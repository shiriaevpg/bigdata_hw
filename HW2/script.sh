#!/bin/sh

set -e

cd hadoop-3.4.0/etc/hadoop

# ===========================================================
# 1-2. Редактируем mapred-site.xml
# ===========================================================
cat > mapred-site.xml << 'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
EOF

echo "mapred-site.xml создан."

# ===========================================================
# 3. Редактируем yarn-site.xml
# ===========================================================
cat > yarn-site.xml << 'EOF'
<?xml version="1.0"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME, HADOOP_COMMON_HOME, HADOOP_HDFS_HOME, HADOOP_CONF_DIR, CLASSPATH_PREPEND_DISTCACHE, HADOOP_YARN_HOME, HADOOP_HOME, PATH, LANG, TZ, HADOOP_MAPRED_HOME</value>
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
</configuration>
EOF

echo "yarn-site.xml создан."

# ===========================================================
# 4. Копируем конфиги на остальные ноды
# ===========================================================
REMOTE_CONF_DIR="/home/hadoop/hadoop-3.4.0/etc/hadoop"

for node in tmpl-dn-00 tmpl-dn-01 tmpl-nn; do
    echo "Копирую mapred-site.xml на $node ..."
    scp mapred-site.xml "${node}:${REMOTE_CONF_DIR}/mapred-site.xml"

    echo "Копирую yarn-site.xml на $node ..."
    scp yarn-site.xml "${node}:${REMOTE_CONF_DIR}/yarn-site.xml"
done

echo "Конфиги скопированы на все ноды."

# ===========================================================
# 5-6. Переходим на Name Node и запускаем YARN
# ===========================================================
echo "Подключаюсь к tmpl-nn и запускаю YARN..."
ssh tmpl-nn << 'REMOTE_EOF'
    set -e

    echo "=== Запуск YARN ==="
    ~/hadoop-3.4.0/sbin/start-yarn.sh

    echo ""
    echo "=== Проверка через jps (YARN) ==="
    jps

    # ===========================================================
    # 8. Запускаем historyserver
    # ===========================================================
    echo ""
    echo "=== Запуск History Server ==="
    ~/hadoop-3.4.0/bin/mapred --daemon start historyserver

    # Даём немного времени на запуск
    sleep 3

    # ===========================================================
    # 9. Проверяем через jps, что historyserver запущен
    # ===========================================================
    echo ""
    echo "=== Проверка через jps (History Server) ==="
    jps
REMOTE_EOF

echo ""
echo "Готово. YARN и History Server запущены на tmpl-nn."

