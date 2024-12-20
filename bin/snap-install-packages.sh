sudo snap set system proxy.http="http://172.16.0.1:3128" 
sudo snap set system proxy.https="http://172.16.0.1:3128"
   
snap refresh
   
snap find 1password
   
sudo snap install 1password
sudo snap install --classic code
sudo snap install --classic obsidian
