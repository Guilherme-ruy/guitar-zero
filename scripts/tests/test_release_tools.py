import base64
from pathlib import Path
import struct
import os
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from scripts.prepare_android_signing import restore_keystore, validate_version
from scripts.verify_play_bundle import verify_bundle, verify_elf, verify_manifest, verify_signing

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
package="io.github.guilhermeruy.guitar_zero" android:versionCode="3">
<uses-sdk android:targetSdkVersion="36"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<application android:debuggable="false"/></manifest>'''

def elf(alignment=16384, relro_end=None, *, load_address=0, load_size=65536,
        relro_address=0, extra_loads=()):
    count = (1 if relro_end is None else 2) + len(extra_loads)
    data = bytearray(64 + 56 * count)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, count)
    struct.pack_into('<I', data, 64, 1)
    struct.pack_into('<I', data, 68, 6)
    struct.pack_into('<Q', data, 80, load_address)
    struct.pack_into('<Q', data, 104, load_size)
    struct.pack_into('<Q', data, 112, alignment)
    if relro_end is not None:
        struct.pack_into('<I', data, 120, 0x6474E552)
        struct.pack_into('<Q', data, 136, relro_address)
        struct.pack_into('<Q', data, 160, relro_end - relro_address)
    first_extra = 1 if relro_end is None else 2
    for index, (address, size, flags) in enumerate(extra_loads, first_extra):
        start = 64 + 56 * index
        struct.pack_into('<II', data, start, 1, flags)
        struct.pack_into('<Q', data, start + 16, address)
        struct.pack_into('<Q', data, start + 40, size)
        struct.pack_into('<Q', data, start + 48, alignment)
    return data

class SigningPreparationTests(unittest.TestCase):
    def test_versions_reject_shell_syntax_and_invalid_codes(self):
        for name, number in [('1.0.0; echo x', '1'), ('1.0', '1'), ('1.0.0', '0'), ('1.0.0', '2100000001'), ('1.0.0', '1\n2')]:
            with self.subTest(name=name, number=number), self.assertRaises(ValueError):
                validate_version(name, number)
        validate_version('1.0.0', '2100000000')

    def test_missing_secrets_never_create_keystore(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'Configure repository secrets'):
                restore_keystore({'BUILD_NAME': '1.0.0', 'BUILD_NUMBER': '1', 'RUNNER_TEMP': directory})
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_only_keystore_path_is_written_to_actions_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            environment_file = Path(directory) / 'actions-env'
            env = {'BUILD_NAME': '1.0.0', 'BUILD_NUMBER': '1', 'RUNNER_TEMP': directory,
                   'GITHUB_ENV': str(environment_file), 'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'test-key-bytes').decode(),
                   'ANDROID_STORE_PASSWORD': 'secret-with-$-and-=', 'ANDROID_KEY_ALIAS': 'upload', 'ANDROID_KEY_PASSWORD': 'other-secret'}
            target = restore_keystore(env)
            self.assertEqual(target.read_bytes(), b'test-key-bytes')
            saved = environment_file.read_text()
            self.assertIn('ANDROID_KEYSTORE_PATH=', saved)
            for name in ('ANDROID_STORE_PASSWORD', 'ANDROID_KEY_PASSWORD', 'ANDROID_KEYSTORE_BASE64'):
                self.assertNotIn(env[name], saved)

    def test_malformed_base64_is_rejected_before_file_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(BUILD_NAME='1.0.0', BUILD_NUMBER='1', RUNNER_TEMP=directory,
                       ANDROID_KEYSTORE_BASE64='invalid???', ANDROID_STORE_PASSWORD='pass',
                       ANDROID_KEY_ALIAS='upload', ANDROID_KEY_PASSWORD='pass')
            with self.assertRaisesRegex(ValueError, 'valid Base64'):
                restore_keystore(env)
            self.assertEqual(list(Path(directory).iterdir()), [])

class BundlePolicyTests(unittest.TestCase):
    def test_current_offline_manifest_is_accepted(self):
        verify_manifest(MANIFEST, '3')

    def test_network_permission_is_rejected_in_any_permission_variant(self):
        for tag in ('uses-permission', 'uses-permission-sdk-23'):
            changed = MANIFEST.replace('<application', f'<{tag} android:name="android.permission.INTERNET"/><application')
            with self.assertRaisesRegex(ValueError, 'INTERNET'):
                verify_manifest(changed)

    def test_identity_sdk_debug_and_version_must_match(self):
        for changed in (MANIFEST.replace('guitar_zero', 'other'), MANIFEST.replace('Version="36"', 'Version="35"'),
                        MANIFEST.replace('debuggable="false"', 'debuggable="true"')):
            with self.assertRaises(ValueError):
                verify_manifest(changed)
        with self.assertRaises(ValueError):
            verify_manifest(MANIFEST, '4')

    def test_16kb_native_segments_are_accepted(self):
        verify_elf(elf())
        verify_elf(elf(65536, 16384))

    def test_4kb_load_and_unaligned_relro_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'LOAD'):
            verify_elf(elf(4096))
        with self.assertRaisesRegex(ValueError, 'RELRO'):
            verify_elf(elf(16384, 4096))

    def test_android_documented_isolated_relro_is_accepted(self):
        # Official Android example: RELRO and its LOAD both span 0x4680..0x5000.
        verify_elf(elf(relro_end=0x5000, relro_address=0x4680,
                       load_address=0x4680, load_size=0x980,
                       extra_loads=((0, 0x680, 5), (0x8000, 0x1000, 6))))

    def test_relro_with_following_writable_data_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'RELRO'):
            verify_elf(elf(relro_end=0xE1000, relro_address=0xDFAF0,
                           load_address=0xDFAF0, load_size=0x4510))

    def test_real_datastore_relro_padding_is_accepted(self):
        # Headers from the arm64 and x86_64 libraries in this project's CI APK.
        verify_elf(elf(relro_end=0x6000, relro_address=0x51C0,
                       load_address=0x51C0, load_size=0x268,
                       extra_loads=((0, 0x11C0, 5), (0x9428, 1, 6))))
        verify_elf(elf(relro_end=0x6000, relro_address=0x4F20,
                       load_address=0x4F20, load_size=0x228,
                       extra_loads=((0, 0xF20, 5),)))

    def test_isolated_relro_must_not_protect_another_writable_load(self):
        for address in (0x4000, 0x6000):
            with self.subTest(address=address), self.assertRaisesRegex(ValueError, 'RELRO'):
                verify_elf(elf(relro_end=0x5000, relro_address=0x4680,
                               load_address=0x4680, load_size=0x980,
                               extra_loads=((address, 0x100, 6),)))

    def test_bundle_failure_identifies_the_native_library(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            bundle = base / 'test.aab'
            manifest = base / 'manifest.xml'
            config = base / 'config.json'
            manifest.write_text(MANIFEST, encoding='utf-8')
            config.write_text('{}', encoding='utf-8')
            library = 'base/lib/arm64-v8a/bad.so'
            with zipfile.ZipFile(bundle, 'w') as archive:
                archive.writestr(library, elf(4096))
            with patch.dict(os.environ, {'BUILD_NUMBER': '3'}):
                with self.assertRaises(ValueError) as raised:
                    verify_bundle(bundle, manifest, config)
            self.assertIn(library + ':', str(raised.exception))
            self.assertIn('LOAD', str(raised.exception))

@unittest.skipUnless(shutil.which('keytool') and shutil.which('jarsigner'), 'JDK signing tools required')
class CertificateIntegrationTests(unittest.TestCase):
    def test_unsigned_upload_signed_and_debug_signed_archives(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            unsigned = base / 'unsigned.aab'
            with zipfile.ZipFile(unsigned, 'w') as archive:
                archive.writestr('base/test.txt', 'A signing fixture, not a Flutter app.')
            with self.assertRaisesRegex(ValueError, 'not signed'):
                verify_signing(unsigned)
            for owner, valid in [('CN=Guitar Zero CI Fixture', True), ('CN=Android Debug,O=Android,C=US', False)]:
                keystore = base / ('upload.jks' if valid else 'debug.jks')
                bundle = base / ('upload.aab' if valid else 'debug.aab')
                env = dict(os.environ, FIXTURE_PASSWORD='test-fixture-only', ANDROID_STORE_PASSWORD='test-fixture-only',
                           ANDROID_KEYSTORE_PATH=str(keystore), ANDROID_KEY_ALIAS='upload')
                subprocess.run(['keytool', '-genkeypair', '-keystore', str(keystore), '-storetype', 'JKS',
                                '-keyalg', 'RSA', '-keysize', '2048', '-validity', '1', '-alias', 'upload',
                                '-dname', owner, '-storepass:env', 'FIXTURE_PASSWORD', '-keypass:env', 'FIXTURE_PASSWORD'],
                               env=env, check=True, capture_output=True)
                subprocess.run(['jarsigner', '-keystore', str(keystore), '-storepass:env', 'FIXTURE_PASSWORD',
                                '-keypass:env', 'FIXTURE_PASSWORD', '-signedjar', str(bundle), str(unsigned), 'upload'],
                               env=env, check=True, capture_output=True)
                with patch.dict(os.environ, env):
                    if valid:
                        self.assertEqual(len(verify_signing(bundle)), 64)
                    else:
                        with self.assertRaisesRegex(ValueError, 'debug certificate'):
                            verify_signing(bundle)

if __name__ == '__main__':
    unittest.main()
