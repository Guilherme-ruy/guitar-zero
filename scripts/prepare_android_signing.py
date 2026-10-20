"""Restore a keystore from Actions secrets without writing passwords to disk."""
import base64
import binascii
import os
from pathlib import Path
import re
import sys

SECRET_NAMES = (
    'ANDROID_KEYSTORE_BASE64', 'ANDROID_STORE_PASSWORD',
    'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD',
)

def validate_version(name, number):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', name):
        raise ValueError('BUILD_NAME must have the form 1.0.0.')
    if not re.fullmatch(r'[1-9][0-9]*', number) or int(number) > 2100000000:
        raise ValueError('BUILD_NUMBER must be an integer from 1 to 2100000000.')

def restore_keystore(env):
    validate_version(env.get('BUILD_NAME', ''), env.get('BUILD_NUMBER', ''))
    missing = [name for name in SECRET_NAMES if not env.get(name)]
    if missing:
        raise ValueError('Configure repository secrets: ' + ', '.join(missing))
    try:
        raw = base64.b64decode(env['ANDROID_KEYSTORE_BASE64'], validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError('ANDROID_KEYSTORE_BASE64 must contain valid Base64.') from error
    if not raw:
        raise ValueError('The keystore is empty.')
    target = Path(env['RUNNER_TEMP']).resolve() / 'guitar-zero-upload.jks'
    with target.open('wb') as file:
        os.chmod(target, 0o600)
        file.write(raw)
    with Path(env['GITHUB_ENV']).open('a', encoding='utf-8') as file:
        file.write(f'ANDROID_KEYSTORE_PATH={target}\n')
    return target

if __name__ == '__main__':
    try:
        restore_keystore(os.environ)
        print('Upload keystore restored. Passwords remain in environment variables.')
    except (ValueError, KeyError, OSError) as error:
        # Error messages name missing settings, never their values.
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
