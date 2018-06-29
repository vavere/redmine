#!/bin/bash
set -e
source ${REDMINE_RUNTIME_DIR}/functions

[[ $DEBUG == true ]] && set -x

case ${1} in
  app:init|app:unicorn|app:start|app:rake|app:backup:create|app:backup:restore)

    initialize_system
    configure_redmine
    configure_cron
    configure_nginx

    case ${1} in
      app:start)
        migrate_database
        install_plugins
        install_themes

        if [[ -f ${REDMINE_DATA_DIR}/entrypoint.custom.sh ]]; then
          echo "Executing entrypoint.custom.sh..."
          . ${REDMINE_DATA_DIR}/entrypoint.custom.sh
        fi

        rm -rf /var/run/supervisor.sock
        exec /usr/bin/supervisord -nc /etc/supervisor/supervisord.conf
        ;;
      app:unicorn)
        exec /usr/local/bin/bundle exec unicorn_rails -E ${RAILS_ENV} -c ${REDMINE_INSTALL_DIR}/config/unicorn.rb
        ;;
      app:init)
        migrate_database
        install_plugins
        install_themes
        ;;
      app:rake)
        shift 1
        execute_raketask $@
        ;;
      app:backup:create)
        shift 1
        backup_create $@
        ;;
      app:backup:restore)
        shift 1
        backup_restore $@
        ;;
    esac
    ;;
  app:nginx)
    initialize_system
    configure_nginx
    exec /usr/sbin/nginx -g "daemon off;"
    ;;
  app:cron)
    initialize_system
    configure_cron
    ln -sf /proc/1/fd/1 /var/log/cron.log
    exec /usr/sbin/cron -f -l 7 -L /var/log/cron.log
    ;;
  app:help)
    echo "Available options:"
    echo " app:start          - Starts the Redmine server (default)"
    echo " app:unicorn        - Start unicorn only"
    echo " app:nginx          - Start nginx only"  
    echo " app:cron           - Start cron only"  
    echo " app:init           - Initialize the Redmine server (e.g. create databases, install plugins/themes), but don't start it."
    echo " app:rake <task>    - Execute a rake task."
    echo " app:backup:create  - Create a backup."
    echo " app:backup:restore - Restore an existing backup."
    echo " app:help           - Displays the help"
    echo " [command]          - Execute the specified command, eg. bash."
    ;;
  *)
    exec "$@"
    ;;
esac
