# osDiscover

osDiscover is a ruby on rails modular application for detecting and analyzing security threats. 
The modular nature of the app means that you can utilize popular security scanners like OpenVAS, 
Arachni, Nikto, Metasploit and more. 

[OpenVAS Protocol Documentation](http://www.openvas.org/protocol-doc.html)(OMP 2.0 and OAP 1.0).


## Getting Started

1. git clone git://github.com/clonesec/osDiscover.git
2. cd osDiscover
3. edit config/app_config.yml and change the OMP/OAP host and port settings per you OpenVAS installation
4. bundle install ... to install all the necessary ruby gems
5. rake db:migrate ... to create a users table to be used by Devise for sign in/out/timeout of user sessions
6. rails server ... then visit http://localhost:3000/ in a web browser

> Note: you must have a user account, probably an admin, set 
> up in OpenVAS as this app actually uses the OpenVAS users.