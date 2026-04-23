import os
import re

path = '/Users/muhnasrul/Documents/Projek Mobile/Flutter/uangku/lib/screens/settings_screen.dart'
with open(path, 'r') as file:
    content = file.read()

# I want to find instances of:
#               ],
#             ),
#           ),
#         ),
#         const SizedBox(height: 10),
# and replace with:
#               ],
#             ),
#         ),
#         const SizedBox(height: 10),

new_content = re.sub(
    r'              \],\n            \),\n          \),\n        \),\n        const SizedBox\(height: (12|10)\),',
    r'              ],\n            ),\n        ),\n        const SizedBox(height: \1),',
    content
)

# And the last one before buttons:
#               ],
#             ),
#           ),
#         ),
#         const SizedBox(height: 12),
#         SizedBox(

new_content = re.sub(
    r'                  \),\n                \),\n              \],\n            \),\n          \),\n        \),\n        const SizedBox\(height: 12\),\n        SizedBox\(',
    r'                  ),\n                ),\n              ],\n            ),\n        ),\n        const SizedBox(height: 12),\n        SizedBox(',
    new_content
)

with open(path, 'w') as file:
    file.write(new_content)
