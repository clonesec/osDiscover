# osDiscover

osDiscover is a Ruby on Rails application that interfaces with OpenVAS servers using 
the [OpenVAS Protocol Documentation](http://www.openvas.org/protocol-doc.html)
(OMP 2.0 and OAP 1.0).

The application offers the same functionality as the [Greenbone Security Assistant (GSA)](http://www.greenbone.net/technology/tool_architecture.html).


## Getting Started

1. git clone git://github.com/clonesec/osDiscover.git
2. cd osDiscover
3. edit config/app_config.yml and change the OMP/OAP host and port settings per you OpenVAS installation
4. bundle install ... to install all the necessary ruby gems
5. rake db:migrate ... to create a users table to be used by Devise for sign in/out/timeout of user sessions
6. rails server ... then visit http://localhost:3000/ in a web browser

> Note: you must have a user account, probably an admin, set 
> up in OpenVAS as this app actually uses the OpenVAS users.
