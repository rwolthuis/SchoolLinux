Rick Init Script:
  cmd.script: 
    - shell: /bin/bash
    - source: salt://script/install_docker_kubernetes.sh
    - name: install_docker_kubernetes