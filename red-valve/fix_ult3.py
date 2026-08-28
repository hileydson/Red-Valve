with open('/tmp/fixed_ult_code.gd', 'r') as f:
    content = f.read()

content = content.replace('current_scene.player.add_child', 'current_scene.add_child')
content = content.replace('cine_cam.player.add_child', 'cine_cam.add_child')
content = content.replace('player_model.player.add_child', 'player_model.add_child')

with open('/tmp/fixed_ult_code.gd', 'w') as f:
    f.write(content)
