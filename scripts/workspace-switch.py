#!/usr/bin/python2.7

import i3
outputs = i3.get_outputs()

# set current workspace to output 0
for display in outputs:
	if outputs[0]['current_workspace'] is not None:
		i3.workspace(outputs[0]['current_workspace'])
		break

# ..and move it to the other output.
# outputs wrap, so the right of the right is left ;)
i3.command('move', 'workspace to output right')

# rinse and repeat
i3.workspace(outputs[1]['current_workspace'])
i3.command('move', 'workspace to output right')