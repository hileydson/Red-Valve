with open('/tmp/fixed_ult_code.gd', 'r') as f:
    content = f.read()

content = content.replace('.player.add_child', '.add_child')
content = content.replace('"player.global_rotation', '"global_rotation')
content = content.replace('"player.global_position', '"global_position')

with open('/tmp/fixed_ult_code.gd', 'w') as f:
    f.write(content)
