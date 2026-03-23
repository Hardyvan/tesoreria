import os
import sys

replacements = {
    'Ã¡': 'á',
    'Ã©': 'é',
    'Ã­': 'í',
    'Ã³': 'ó',
    'Ãº': 'ú',
    'Ã±': 'ñ',
    'Ã ': 'Á',
    'Ã‰': 'É',
    'Ã\x8d': 'Í',
    'Ã“': 'Ó',
    'Ãš': 'Ú',
    'Ã‘': 'Ñ',
    'âš': '⚠️'
}

def fix_encoding(directory):
    count = 0
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    changed = False
                    for bad, good in replacements.items():
                        if bad in content:
                            content = content.replace(bad, good)
                            changed = True
                    
                    if changed:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(content)
                        print(f"Fixed UTF-8 in {filepath}")
                        count += 1
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")
    print(f"Done. Fixed {count} files.")

if __name__ == '__main__':
    fix_encoding(r'f:\Cosas de Ivan\tesoreria_ivan\lib')
