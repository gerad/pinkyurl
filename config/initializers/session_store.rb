# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_pinkyurl_session',
  :secret      => 'e531efa975b454eee0122cba9d69dad1b470018ce62efbba21ac4134c5215dc08f9cfb5fde31f4d288fed67c65d5e6d0a533d906cfca57ee6c5baf12c111a08e'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
