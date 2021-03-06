#ensure this is created - but if you know what is good for you then...
#create and mount this from a persistent volume
directory node['base2-fast-elk-docker']['elasticsearch']['data_path'] do
  recursive true
  mode '0777'
end

#don't f with linked containers and get hangs
#do this in reverse
%w{nginx kibana logstash elasticsearch}.each do | container |
  execute "clear linked containers" do
    command <<-EOF
      docker ps -a | grep -q #{container} && docker rm -f #{container} || echo #{container} not there
    EOF
  end
end

# export ES_HEAP_SIZE
# export ES_HEAP_NEWSIZE
# export ES_DIRECT_SIZE
# export ES_JAVA_OPTS
# export ES_GC_LOG_FILE
docker_container 'elasticsearch' do
  tag 'latest'
  command '/entrypoint.sh'
  port [ '9200:9200', '9300:9300']
  env [
    "ES_HEAP_SIZE=#{node['base2-fast-elk-docker']['elasticsearch']['heapsize']}"
  ]
  volumes [
    "#{node['base2-fast-elk-docker']['elasticsearch']['data_path']}:#{node['base2-fast-elk-docker']['elasticsearch']['data_path']}",
    "/var/config/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml",
    "/var/config/elasticsearch/docker-entrypoint.sh:/entrypoint.sh"
  ]
  log_driver = "json-file"
  log_opts "max-size=1g" #log_opts ["max-size=1g", "max-file=2", "labels=label1,label2", "env=evn1,env2"]
  detach true
  restart_policy 'always'
  action ["redeploy"]
end

docker_container 'logstash' do
  tag 'latest'
  command 'logstash -f /etc/logstash/conf.d/logstash.conf'
  volumes [ '/var/config/logstash:/etc/logstash/conf.d/logstash.conf']
  port [ '5000:5000', '3515:3515', '3516:3516', '3519:3519', '3520:3520', '3521:3521', '3522:3522', '3523:3523', '5140:5140' ]
  links [ 'elasticsearch:elasticsearch' ]
  log_driver = "json-file"
  log_opts "max-size=1g" #log_opts ["max-size=1g", "max-file=2", "labels=label1,label2", "env=evn1,env2"]
  detach true
  restart_policy 'always'
  action ["redeploy"]
end

docker_container 'kibana' do
  tag 'latest'
  port [ '5601:5601' ]
  links [ 'elasticsearch:elasticsearch' ]
  env [ 'ELASTICSEARCH_URL=http://elasticsearch:9200' ]
  log_driver = "json-file"
  log_opts "max-size=1g" #log_opts ["max-size=1g", "max-file=2", "labels=label1,label2", "env=evn1,env2"]
  detach true
  restart_policy 'always'
  action ["redeploy"]
end

docker_container 'nginx' do
  tag 'latest'
  port [ '80:80' ]
  links [ 'kibana:kibana' ]
  volumes [ "/var/config/nginx/nginx.conf:/etc/nginx/conf.d/default.conf", "/var/config/nginx/htpasswd.users:/etc/nginx/htpasswd.users" ]
  log_driver = "json-file"
  log_opts "max-size=1g" #log_opts ["max-size=1g", "max-file=2", "labels=label1,label2", "env=evn1,env2"]
  detach true
  restart_policy 'always'
  action ["redeploy"]
end

#TODO:
#logrotate
