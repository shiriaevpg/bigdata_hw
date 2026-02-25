Задание:

Необходимо задокументировать или реализовать автоматизированное развертывание кластера hdfs, включающего в себя 3 DataNode и обязательные для функционирования кластера сервисы: NameNode, Secondary NameNode.


1. Подготовка
Устанавливаем tmux, запускаем
```
sudo apt install tmux
tmux
```
Генерируем ключи
```
ssh-keygen
cat .ssh/id_ed25519.pub >> .ssh/authorized_keys
```

Копируем их на все узлы

```
scp .ssh/authorized_keys 192.168.10.20
scp .ssh/authorized_keys 192.168.10.21
scp .ssh/authorized_keys 192.168.10.22
scp .ssh/authorized_keys 192.168.10.54
```

2. Изменение /etc/hosts
hosts на entrypoint:
```
127.0.0.1       tmpl-jn
192.168.10.22   tmpl-nn
192.168.10.20   tmpl-dn-00
192.168.10.21   tmpl-dn-01

```
Аналогично надо изменить все /etc/hosts нод.

3. Создание пользователя hadoop

```
sudo adduser hadoop
```
Этого пользователя надо добавить на все ноды.

```
sudo -i -u hadoop
```




От пользователя hadoop entrypoint-а надо закинуть ключ на остальные ноды:
```
ssh-keygen && cat .ssh/id_ed25519.pub > .ssh/authorized_keys
scp -r .ssh/ tmpl-nn:/home/hadoop
scp -r .ssh/ tmpl-dn-00:/home/hadoop
scp -r .ssh/ tmpl-dn-01:/home/hadoop
```
4. Скачивание и установка Hadoop:
```
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz
scp hadoop-3.4.0.tar.gz tmpl-nn:/home/hadoop
scp hadoop-3.4.0.tar.gz tmpl-dn-00:/home/hadoop
scp hadoop-3.4.0.tar.gz tmpl-dn-01:/home/hadoop
tar -xzvf hadoop-3.4.0.tar.gz
```

Проверим версию java:
```
java -version
which java
readlink -f /usr/bin/java # из which
/usr/lib/jvm/java-8-openjdk-amd64/bin/java # из readlink
```

Добавляем переменные окружения, и применим изменения
```
export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

```
source .profile
```

Аналогичные действия проводим с остальными нодами.

5. Конфигурация hadoop
```
cd hadoop-3.4.0/etc/hadoop
```

В hadoop-env.sh надо добавить строку
```
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
```
В core-site.xml, configuration пишем следующее:
```
<property>
	<name>fs.defaultFS</name>
	<value>hdfs://tmpl-nn:9000</value>
</property>
```

В hdfs-site.xml, configuration пишем следующее:
```
<property>
	<name>dfs.replication</name>
	<value>3</value>
</property>
```

В workers:

комментируем localhost, и вместо него указываем имена узлов, на которых будут запущены сервисы DataNode:
```
tmpl-nn
tmpl-dn-00
tmpl-dn-01
```

Аналогичные действия проводим с остальными нодами.


На всех нодах нужно установить соответствующее имя хоста (tmpl-jn, tmpl-nn, tmpl-dn-00, tmpl-dn-01), 


Теперь все готово для запуска hadoop!
Подключимся к NameNode:
```
ssh tmpl-nn
cd hadoop-3.4.0
bin/hdfs namenode -format # создаём и форматируем файловую систему
sbin/start-dfs.sh 		  # запуск кластера
```

Проверить работоспособность можно с помощью 
```
jps
```

На entrypoint будем видеть DataNode, Jps, SecondaryNameNode, NameNode

На DataNode ожидаем DataNode и Jps.	
