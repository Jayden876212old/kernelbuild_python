import re
import subprocess

latest_kernel_ver = subprocess.check_output(['pacman', '-Ss', 'linux'])
latest_kernel_ver = str(latest_kernel_ver)
a, b = latest_kernel_ver.find('core/linux '), latest_kernel_ver.find('.arch')
latest_kernel_ver.find('6.7.1')
print(latest_kernel_ver[a+11:b])
