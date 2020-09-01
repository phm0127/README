echo "> 백엔드 pid 확인"​ 
CURRENT_PID=$(ps -ef | grep java | grep study* | awk '{print $2}') 
echo "$CURRENT_PID"
 if [ -z $CURRENT_PID ]; then
 echo "> 현재 구동중인 애플리케이션이 없으므로 종료하지 않습니다." 
else
 echo "> kill -9 $CURRENT_PID" 
kill -9 $CURRENT_PID 
sleep 10 
fi
 echo "> 새 백엔드 서버 구동" 
 nohup java -jar /home/ubuntu/sns/backend/deploy/study-0.0.1-SNAPSHOT.jar >> /home/ubuntu/sns/backend/logs/studySys.log &
