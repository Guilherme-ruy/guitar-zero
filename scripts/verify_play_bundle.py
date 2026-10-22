"""Fail a Play artifact with the wrong identity, signing, or native alignment."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

ANDROID = '{http://schemas.android.com/apk/res/android}'
PACKAGE = 'io.github.guilhermeruy.guitar_zero'

def verify_manifest(text, expected_version=None):
    root = ET.fromstring(text)
    if root.get('package') != PACKAGE:
        raise ValueError('The package identity changed.')
    version = root.get(ANDROID + 'versionCode')
    if not version or int(version) < 1 or (expected_version and version != expected_version):
        raise ValueError('The versionCode does not match this release.')
    sdk = root.find('uses-sdk')
    if sdk is None or int(sdk.get(ANDROID + 'targetSdkVersion', '0')) < 36:
        raise ValueError('This release must target Android API 36 or newer.')
    permissions = {node.get(ANDROID + 'name') for node in root if node.tag.startswith('uses-permission')}
    if 'android.permission.INTERNET' in permissions:
        raise ValueError('The offline app must not request INTERNET.')
    if 'android.permission.RECORD_AUDIO' not in permissions:
        raise ValueError('The tuner microphone permission is missing.')
    app = root.find('application')
    if app is None or app.get(ANDROID + 'debuggable') == 'true':
        raise ValueError('The application must not be debuggable.')

def verify_elf(data):
    if data[:4] != b'\x7fELF' or data[4] != 2:
        raise ValueError('Expected an ELF64 native library.')
    order = '<' if data[5] == 1 else '>'
    offset = struct.unpack_from(order + 'Q', data, 32)[0]
    entry_size, count = struct.unpack_from(order + 'HH', data, 54)
    if entry_size < 56 or not count:
        raise ValueError('Native program headers are invalid.')
    loads = []
    relros = []
    for index in range(count):
        start = offset + index * entry_size
        kind = struct.unpack_from(order + 'I', data, start)[0]
        flags = struct.unpack_from(order + 'I', data, start + 4)[0]
        address = struct.unpack_from(order + 'Q', data, start + 16)[0]
        memory_size = struct.unpack_from(order + 'Q', data, start + 40)[0]
        alignment = struct.unpack_from(order + 'Q', data, start + 48)[0]
        if kind == 1:
            loads.append((address, address + memory_size, flags))
            if alignment < 16384 or alignment & (alignment - 1):
                raise ValueError('A native LOAD segment does not support 16 KB alignment.')
        if kind == 0x6474E552:
            relros.append((address, address + memory_size))
    if not loads:
        raise ValueError('Native LOAD segments are missing.')
    for address, end in relros:
        if end % 16384 == 0:
            continue
        # Android permits an unaligned end when RELRO owns its entire LOAD.
        # Rounding protection to 16 KB must not cover another writable LOAD.
        # RELRO may include trailing padding beyond the LOAD's memory size.
        isolated = any(start == address and address < stop <= end for start, stop, _ in loads)
        page_start = address // 16384 * 16384
        page_end = (end + 16383) // 16384 * 16384
        overlaps_writable = any(
            flags & 2 and stop > start and start < page_end and stop > page_start
            and not (address <= start and stop <= end)
            for start, stop, flags in loads
        )
        if not isolated or overlaps_writable:
            raise ValueError('A native RELRO segment is not safe on 16 KB pages.')

def command(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, check=False)
    if result.returncode:
        # Never echo subprocess output or arguments containing signing settings.
        raise ValueError('Signing verification command failed: ' + arguments[0])
    return result.stdout

def first_certificate(text):
    match = re.search(r'-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----', text, re.S)
    if not match:
        raise ValueError('A signing certificate was not found.')
    return base64.b64decode(re.sub(r'\s+', '', match.group(1)))

def verify_signing(bundle):
    java_locale = ['-J-Duser.language=en', '-J-Duser.country=US']
    verified = command(['jarsigner', *java_locale, '-verify', str(bundle)])
    if 'jar verified.' not in verified:
        raise ValueError('The AAB is not signed or its JAR signature is invalid.')
    uploaded = first_certificate(command([
        'keytool', *java_locale, '-exportcert', '-rfc',
        '-keystore', os.environ['ANDROID_KEYSTORE_PATH'],
        '-alias', os.environ['ANDROID_KEY_ALIAS'],
        '-storepass:env', 'ANDROID_STORE_PASSWORD',
    ]))
    signed = first_certificate(command(['keytool', *java_locale, '-printcert', '-rfc', '-jarfile', str(bundle)]))
    if uploaded != signed:
        raise ValueError('The AAB certificate does not match the upload keystore.')
    details = command(['keytool', *java_locale, '-printcert', '-jarfile', str(bundle)])
    if 'CN=Android Debug' in details:
        raise ValueError('A debug certificate cannot be used for Play publication.')
    return hashlib.sha256(signed).hexdigest()

def verify_bundle(bundle, manifest, config):
    verify_manifest(Path(manifest).read_text(encoding='utf-8'), os.environ.get('BUILD_NUMBER'))
    configuration = json.loads(Path(config).read_text(encoding='utf-8'))
    libraries = configuration.get('optimizations', {}).get('uncompressNativeLibraries', {})
    if libraries.get('enabled') and libraries.get('alignment') != 'PAGE_ALIGNMENT_16K':
        raise ValueError('The bundle requests uncompressed native libraries without 16 KB ZIP alignment.')
    count = 0
    with zipfile.ZipFile(bundle) as archive:
        for name in archive.namelist():
            if name.endswith('.so') and any('/lib/' + abi + '/' in name for abi in ('arm64-v8a', 'x86_64')):
                try:
                    verify_elf(archive.read(name))
                except ValueError as error:
                    raise ValueError(f'{name}: {error}') from error
                count += 1
    fingerprint = verify_signing(bundle)
    print(f'Validated package, API, permissions, upload certificate and {count} ELF64 libraries.')
    print('Upload certificate SHA-256 (public): ' + fingerprint)

if __name__ == '__main__':
    try:
        verify_bundle(*sys.argv[1:])
    except (ValueError, OSError, KeyError, ET.ParseError, struct.error, zipfile.BadZipFile) as error:
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
