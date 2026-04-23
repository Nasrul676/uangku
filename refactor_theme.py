import os
import re

files = [
    'lib/screens/expense_input_screen.dart',
    'lib/screens/income_input_screen.dart',
    'lib/screens/transfer_screen.dart',
    'lib/screens/input_screen.dart',
    'lib/screens/dashboard_screen.dart'
]

base_dir = '/Users/muhnasrul/Documents/Projek Mobile/Flutter/uangku'

for f in files:
    path = os.path.join(base_dir, f)
    if not os.path.exists(path): continue
    
    with open(path, 'r') as file:
        content = file.read()
    
    # Replace the border
    new_content = re.sub(
        r'border:\s*Border\.all\(color:\s*const\s*Color\(0xFF111111\),\s*width:\s*[0-9.]+\),?',
        r'border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,',
        content
    )
    
    # Replace specific text color 
    new_content = re.sub(
        r'color:\s*const\s*Color\(0xFF111111\)',
        r'color: AppTheme.borderColor',
        new_content
    )
    
    # Add import if extension is used
    if 'AppThemeExtension' in new_content and 'app_theme.dart' not in new_content:
        new_content = new_content.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';\nimport '../theme/app_theme.dart';"
        )

    with open(path, 'w') as file:
        file.write(new_content)

print("Refactoring complete.")
