
{{- define "local_path_storage.containers" -}}
- name: {{.Values.local_path_storage.deployment.name}}
  image: {{.Values.local_path_storage.image.name}}:{{.Values.local_path_storage.image.version}}
  imagePullPolicy: {{.Values.local_path_storage.deployment.imagePullPolicy}}
  command:
    - {{.Values.local_path_storage.deployment.name}}
    - --debug
    - start
    - --config
    - /etc/config/config.json
  volumeMounts:
    - name: config-volume
      mountPath: /etc/config/
  env:
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: CONFIG_MOUNT_PATH
      value: /etc/config/
{{- end }}


{{- define "local_path_storage.configmap" -}}
config.json: |-
  {
          "nodePathMap":[
          {
                  "node":"DEFAULT_PATH_FOR_NON_LISTED_NODES",
                  "paths":["/opt/local-path-provisioner"]
          }
          ]
  }
setup: |-
  #!/bin/sh
  set -eu
  mkdir -m 0777 -p "$VOL_DIR"
teardown: |-
  #!/bin/sh
  set -eu
  rm -rf "$VOL_DIR"
helperPod.yaml: |-
  apiVersion: v1
  kind: Pod
  metadata:
    name: helper-pod
  spec:
    priorityClassName: system-node-critical
    tolerations:
      - key: node.kubernetes.io/disk-pressure
        operator: Exists
        effect: NoSchedule
    containers:
      - name: helper-pod
        image: docker.io/library/busybox
        imagePullPolicy: IfNotPresent
{{- end }}

# -------------------------------------
{{- define "zookeeper.specs" -}}
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: {{.Values.zookeeper.labels.name}}
        topologyKey: kubernetes.io/hostname
containers:
  - name: {{.Values.zookeeper.name}}
    image: {{.Values.zookeeper.image.name}}:{{.Values.zookeeper.image.version}}
    command:
      - bash
      - -c
      - |
        export ZOOKEEPER_SERVER_ID=$((${HOSTNAME##*-} + 1))
        /etc/confluent/docker/run
    ports:
      - containerPort: {{.Values.zookeeper.port.client}}
      - containerPort: {{.Values.zookeeper.port.follower}}
      - containerPort: {{.Values.zookeeper.port.election}}
    env:
      - name: KAFKA_OPTS
        value: "-Dzookeeper.4lw.commands.whitelist=ruok,stat,srvr"
      - name: ZOOKEEPER_SERVER_COUNT
        value: "3"
      - name: ZOOKEEPER_CLIENT_PORT
        value: "2181"
      - name: ZOOKEEPER_TICK_TIME
        value: "2000"
      - name: ZOOKEEPER_INIT_LIMIT
        value: "5"
      - name: ZOOKEEPER_SYNC_LIMIT
        value: "2"
      - name: ZOOKEEPER_SERVERS
        value: "{{.Values.zookeeper.name}}-0.{{.Values.zookeeper.headless_service.name}}.{{.Values.kafka.namespace.name}}.svc.{{.Values.cluster.name}}:{{.Values.zookeeper.port.follower}}:{{.Values.zookeeper.port.election}};{{.Values.zookeeper.name}}-1.{{.Values.zookeeper.headless_service.name}}.{{.Values.kafka.namespace.name}}.svc.{{.Values.cluster.name}}:{{.Values.zookeeper.port.follower}}:{{.Values.zookeeper.port.election}};{{.Values.zookeeper.name}}-2.{{.Values.zookeeper.headless_service.name}}.{{.Values.kafka.namespace.name}}.svc.{{.Values.cluster.name}}:{{.Values.zookeeper.port.follower}}:{{.Values.zookeeper.port.election}}"
      - name: ZOOKEEPER_DATA_DIR
        value: /var/lib/zookeeper/data
      - name: ZOOKEEPER_LOG_DIR
        value: /var/lib/zookeeper/log
    volumeMounts:
      - name: zookeeper-data
        mountPath: /var/lib/zookeeper/data
      - name: zookeeper-log
        mountPath: /var/lib/zookeeper/log
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
    readinessProbe:
      exec:
        command:
          - /bin/bash
          - -c
          - echo ruok | nc localhost 2181 | grep imok
      initialDelaySeconds: 15
      periodSeconds: 10
    livenessProbe:
      exec:
        command:
          - /bin/bash
          - -c
          - echo ruok | nc localhost 2181 | grep imok
      initialDelaySeconds: 30
      periodSeconds: 15
{{- end }}
# -------------------------------------
{{- define "kafka.configmap" -}}
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
num.partitions=3
num.recovery.threads.per.data.dir=1
log.dirs=/var/kafka/data
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=3000
auto.create.topics.enable=true
delete.topic.enable=true
{{- end}}