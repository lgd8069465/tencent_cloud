cd  /qcloud_init/stargate_linux_install_v1.2.6
./install.sh gzvpc
cd  /qcloud_init/basic_linux_install_1.0.60
./install.sh gzvpc
cd  /qcloud_init/ydeyes_linux_install_0320
./install.sh gzvpc
cd  /qcloud_init/agenttools_linux_uninstall
./uninstall.sh gzvpc
ls -l /qcloud_init/ >> /tmp/cvm_init.log
rm -rf /qcloud_init/
