"""Skip expensive app jobs only when every changed path is inside site/."""
import json
import os
from pathlib import Path
import re
import subprocess


def app_changed(event_name, event, diff_paths):
    if event_name == 'workflow_dispatch':
        return True
    if event_name == 'pull_request':
        base = event['pull_request']['base']['sha']
        head = event['pull_request']['head']['sha']
        separator = '...'
    elif event_name == 'push':
        base, head = event['before'], event['after']
        if set(base) == {'0'}:
            return True  # First push on a branch validates the app baseline.
        separator = '..'
    else:
        return True
    if not all(re.fullmatch(r'[0-9a-f]{40,64}', sha) for sha in (base, head)):
        raise ValueError('Unexpected Git commit identifier')
    paths = diff_paths(base + separator + head)
    return any(not path.startswith('site/') for path in paths)


def git_paths(comparison):
    # Disabling rename detection includes both old and new paths when files move.
    result = subprocess.run(
        ['git', 'diff', '--no-renames', '--name-only', '-z', comparison, '--'],
        check=True, stdout=subprocess.PIPE,
    )
    return [path.decode('utf-8', errors='surrogateescape')
            for path in result.stdout.split(b'\0') if path]


if __name__ == '__main__':
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
    changed = app_changed(os.environ['GITHUB_EVENT_NAME'], event, git_paths)
    with Path(os.environ['GITHUB_OUTPUT']).open('a', encoding='utf-8') as output:
        output.write(f'app={str(changed).lower()}\n')
    print('App changes detected; running app checks.' if changed else
          'Only website changes; app tests and APK build skipped.')
