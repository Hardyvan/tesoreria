import os
import glob

dir_path = r'f:\Cosas de Ivan\tesoreria_ivan\api_tesoreria'
files = glob.glob(os.path.join(dir_path, '**', '*.php'), recursive=True)

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content.replace("'Flutter API'", "'{$dispositivoGlobal}'")
    
    if new_content != content:
        with open(file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Modified {file}')
