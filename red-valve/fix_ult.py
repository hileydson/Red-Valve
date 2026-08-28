import re

with open('/tmp/ult_code.gd', 'r') as f:
    content = f.read()

# Member variables/methods to prepend with 'player.'
members = [
    "is_using_ultimate",
    "cogblade_power_value",
    "cogblade_pulsing",
    "cogblade_pulse_tween",
    "cogblade_particles",
    "cogblade_hud",
    "is_blade_returning",
    "crescent_cogblade",
    "magic_blade_pos_original",
    "control_magic",
    "control_weapons",
    "hand_with_pistol",
    "hand_with_magic",
    "point",
    "hud_layer",
    "playback",
    "velocity",
    "camera",
    "global_position",
    "global_rotation",
    "ult_model_distance",
    "ult_cogblade_rot_x",
    "ult_cogblade_rot_y",
    "ult_cogblade_rot_z"
]

for member in members:
    # We want to replace whole words only if not preceded by a dot
    # e.g. not player.is_using_ultimate if it's already there
    content = re.sub(r'(?<!\.)\b' + member + r'\b', 'player.' + member, content)

# specific method replacements
content = content.replace('get_node_or_null("maycow_lopes")', 'player.get_node_or_null("maycow_lopes")')
content = content.replace('add_child(', 'player.add_child(')

with open('/tmp/fixed_ult_code.gd', 'w') as f:
    f.write(content)
