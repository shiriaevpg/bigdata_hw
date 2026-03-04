Настройка и запуск YARN

Для настройки достаточно запустить script.sh с jumpnode под пользователем hadoop. Альтернативно, можно воспользоваться инструкцией. Внезависимости от выбора настройки,  веб интерфейсы можно будет посмотреть в браузере, исполнив на локальной машине 
```sh
ssh -L 9870:192.168.10.22:9870 -L 8088:192.168.10.22:8088 -L 19888:192.168.10.22:19888 ubuntu@178.236.25.102
```

И зайдя на
- localhost:9870 для hdfs
- localhost:8088 для yarn
- localhost:19888 для history-server

В директории `hadoop-3.4.0/etc/hadoop` редактируем конфигурационные файлы.

В `mapred-site.xml`, в секцию `configuration` добавляем свойства, указывающие использовать YARN и классpath для MapReduce:
```
<property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
</property>
<property>
    <name>mapreduce.application.classpath</name>
    <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
</property>
```

В `yarn-site.xml`, в секцию `configuration` прописываем настройки вспомогательных служб и адреса ResourceManager (наш NameNode - `tmpl-nn`):
```
<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
</property>
<property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
</property>
<property>
    <name>yarn.resourcemanager.hostname</name>
    <value>tmpl-nn</value>
</property>
<property>
    <name>yarn.resourcemanager.address</name>
    <value>tmpl-nn:8032</value>
</property>
<property>
    <name>yarn.resourcemanager.resource-tracker.address</name>
    <value>tmpl-nn:8031</value>
</property>
```

Копируем обновленные конфигурационные файлы на все ноды кластера (`tmpl-dn-00`, `tmpl-dn-01`, `tmpl-nn`) в директорию `/home/hadoop/hadoop-3.4.0/etc/hadoop`.

Запуск YARN и History Server выполняется на NameNode.
Подключимся к `tmpl-nn`:
```
ssh tmpl-nn
```

Запускаем сервисы:
```
~/hadoop-3.4.0/sbin/start-yarn.sh
~/hadoop-3.4.0/bin/mapred --daemon start historyserver
```

Проверить работоспособность можно с помощью 
```
jps
```

На NameNode (`tmpl-nn`) должны быть запущены: `ResourceManager`, `JobHistoryServer`.
На DataNode (`tmpl-dn-00`, `tmpl-dn-01`) должны быть запущены: `NodeManager`.





