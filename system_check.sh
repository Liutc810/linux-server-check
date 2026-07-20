#!/bin/bash
# Linux服务器自动化巡检脚本 + 邮件异常告警
MAIL_TO="3452626689@qq.com"
MAIL_FROM="3452626689@qq.com"
MAIL_SMTP_PWD="fydrcminsyczcihj"
SMTP_SERVER="smtp.163.com"
SMTP_PORT=465

# 巡检阈值配置
MEM_WARN=80    # 内存使用率告警阈值%
DISK_WARN=85   # 磁盘使用率告警阈值%
LOAD_WARN=4    # CPU负载告警阈值

# 初始化日志文件
LOG_FILE="./system_check_$(date +%Y%m%d_%H%M%S).log"
echo "==================== 服务器巡检报告 $(date) ====================" >> $LOG_FILE

# 1. 系统基础信息
echo -e "\n【1.系统基础信息】" >> $LOG_FILE
echo "主机名: $(hostname)" >> $LOG_FILE
echo "系统版本: $(cat /etc/os-release | grep NAME)" >> $LOG_FILE
echo "内核版本: $(uname -r)" >> $LOG_FILE
echo "运行时长: $(uptime | awk '{print $3,$4}' | sed 's/,//')" >> $LOG_FILE

# 2. CPU负载检测
echo -e "\n【2.CPU负载信息】" >> $LOG_FILE
LOAD=$(uptime | awk '{print $NF}')
echo "15分钟负载: $LOAD" >> $LOG_FILE
IS_WARN=0
if [ $(echo "$LOAD > $LOAD_WARN" | bc) -eq 1 ];then
    echo "⚠️ CPU负载过高，触发告警！当前负载$LOAD" >> $LOG_FILE
    IS_WARN=1
fi

# 3. 内存使用检测
echo -e "\n【3.内存使用信息】" >> $LOG_FILE
MEM_TOTAL=$(free -m | awk '/Mem/{print $2}')
MEM_USED=$(free -m | awk '/Mem/{print $3}')
MEM_RATE=$(echo "scale=2;$MEM_USED/$MEM_TOTAL*100" | bc)
echo "总内存:${MEM_TOTAL}M 已使用:${MEM_USED}M 使用率:${MEM_RATE}%" >> $LOG_FILE
if [ $(echo "$MEM_RATE > $MEM_WARN" | bc) -eq 1 ];then
    echo "⚠️ 内存占用过高，触发告警！阈值${MEM_WARN}%" >> $LOG_FILE
    IS_WARN=1
fi

# 4. 磁盘分区检测
echo -e "\n【4.磁盘分区使用】" >> $LOG_FILE
df -h | grep -v tmpfs | grep -v loop >> $LOG_FILE
DISK_LIST=$(df -h | grep -v tmpfs | grep -v loop | awk 'NR>1 {print $5,$1}')
while read line;do
    USE_RATE=$(echo $line | awk '{print $1}' | sed 's/%//')
    DISK_NAME=$(echo $line | awk '{print $2}')
    if [ $USE_RATE -gt $DISK_WARN ];then
        echo "⚠️ 磁盘$DISK_NAME使用率${USE_RATE}%，超过阈值${DISK_WARN}%" >> $LOG_FILE
        IS_WARN=1
    fi
done <<< "$DISK_LIST"

# 5. 运行中的服务端口
echo -e "\n【5.监听端口列表】" >> $LOG_FILE
ss -tulnp >> $LOG_FILE

# 邮件发送函数
send_mail(){
    cat $LOG_FILE | mailx -s "【服务器异常告警】$(hostname)资源超标" \
    -r $MAIL_FROM \
    -S smtp=$SMTP_SERVER \
    -S smtp-auth=login \
    -S smtp-auth-user=$MAIL_FROM \
    -S smtp-auth-password=$MAIL_SMTP_PWD \
    -S smtp-ssl=yes \
    -S smtp-port=$SMTP_PORT \
    $MAIL_TO
}

# 判断是否触发告警，异常则发送邮件
if [ $IS_WARN -eq 1 ];then
    echo -e "\n检测到资源异常，正在发送告警邮件..." >> $LOG_FILE
    send_mail
else
    echo -e "\n所有资源指标正常，无告警" >> $LOG_FILE
fi

echo "巡检完成，报告保存至: $LOG_FILE"
cat $LOG_FILE
