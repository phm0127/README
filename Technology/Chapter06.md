## 트랜잭션 코드의 분리
지금까지 UserService 클래스에 추상화 기법을 적용해 트랜잭션 기술에 독립적으로 만들어줬다. 하지만 여전히 찜찜한 구석이 있다. 트랜잭션 경계설정을 위해 넣은 코드 때문이다.  
스프링이 제공하는 깔끔한 트랜잭션 인터페이스를 썼음에도 비즈니스 로직이 주가 되어야 할 메소드 안에 트랜잭션 경계설정 하는 코드가 더 많은 자리를 차지하고 있다.  
<br>  
### 메소드 분리

~~~java
public void upgradeLevels() {
  PlatformTransactionManager transactionManager =
            new DataSourceTransActionManger(dataSource);
  
  TransactionStatus status = 
            transactionManager.getTransaction(new DefaultTransactionDefinition());
  
  try{
    List<User> users= userDao.getAll();
    for(User user : users){
      if(canUpgradeLevel(user)){
        upgradeLevel(user);
      }
    }
    transactionManager.commit(status);
  }
  catch(Exception e){
    transactionManager.rollback(status);
    throw e;
  }
}
~~~

얼핏보면 트랜잭션 경계설정 코드와 비즈니스 로직 코드가 복잡하게 얽혀 있는 듯이 보이지만 자세히 살펴보면 비즈니스 로직 코드를 사이에 두고 트랜잭션 시작과 종료를 담당하는 코드가 앞뒤에 위치하고 있다. 또, 이 코드의 특징은 성격이 다른 두 코드가 서로 주고받는 정보가 없다는 점이다. 
따라서, 이 두 코드는 성격이 다를 뿐만 아니라 서로 주고받는 것도 없는 완벽하게 독립적인 코드다.

~~~java
public void upgradeLevels() {
  PlatformTransactionManager transactionManager =
            new DataSourceTransActionManger(dataSource);
  
  TransactionStatus status = 
            transactionManager.getTransaction(new DefaultTransactionDefinition());
  
  try{
    upgradeLevelsInternal();
    transactionManager.commit(status);
  }
  catch(Exception e){
    transactionManager.rollback(status);
    throw e;
  }
}


private void upgradeLevelsInternal(){
  List<User> users= userDao.getAll();
    for(User user : users){
      if(canUpgradeLevel(user)){
        upgradeLevel(user);
      }
    }
}
~~~

따라서 위 코드처럼 비즈니스 로직을 담당하는 코드를 메소드로 추출해서 독립시킬 수 있다. 이렇게 코드를 분리하고 나니 한결 깔끔해졌다. 적어도 사용자가 레벨 업그레이드를 담당하는 비즈니스 로직을 수정하다가 실수로 트랜잭션 코드를 건드릴 일도 없어졌다.  
비즈니스 로직을 담당하는 코드가 깔끔하게 분리돼서 보기 좋긴 하지만 여전히 트랜잭션을 담당하는 기술적인 코드가 버젓이 UserService 안에 자리 잡고 있다. 우리는 기존에 인터페이스를 통해 Client와 UserService간의 느슨한 결합을 갖는 구조였다.  

<br>

<img width="50%" alt="스크린샷 2021-03-16 오후 3 58 59" src="https://user-images.githubusercontent.com/7456710/111268475-ac4b3080-8670-11eb-83f8-90026e9e2fac.png">

<br><br>
보통 이렇게 인터페이스를 통해 구현 클래스를 클라이언트에 노출하지 않고 런타임 시에 DI를 통해 적용하는 방법을 쓰는 이유는, 일반적으로 구현 클래스를 바꿔가면서 사용하기 위해서다. 하지만 이번에는 한번에 두 개의 UserService 인터페이스 구현 클래스를 동시에 이용한다면 어떨까?  

<br>

![image](https://user-images.githubusercontent.com/7456710/111268881-398e8500-8671-11eb-9f54-6f4a9ab94a4a.png)

<br><br>

우리가 지금 해결하려고 하는 문제는 UserService에는 순수하게 비즈니스 로직을 담고 트랜잭션 경계설정을 담당하는 코드를 외부로 빼내려는 것이다. 하지만 클라이언트가 UserService의 기능을 제대로 이용하려면 트랜잭션이 적용돼야 한다. 
그렇게 하기 위해서 위의 그림과 같은 구조를 생각해 볼 수 있다. UserServiceImpl에는 비즈니스 로직만 담고 UserServiceTx에는 트랜잭션 경계를 설정해주는 코드를 담는다. UserServiceTx는 비즈니스 로직을 담지 않고 단지 트랜잭션의 경계설정이라는 책임만 맡을 뿐이다.  
<br><br>
##### 아래 코드는 각각 UserServiceImpl, UserServiceTx 클래스의 코드이다.  

~~~java
public class UserServiceImpl implements UserService{
  UserDAO userDao;

  public void upgradeLevelsInternal(){
    List<User> users= userDao.getAll();
      for(User user : users){
        if(canUpgradeLevel(user)){
          upgradeLevel(user);
        }
      }
  }
}
~~~

<br>

~~~java
public class UserServiceTx implements UserService{
  UserService userService;
  
  public void setUserService(UserService userService){
    this.userService=userService;
  }
  
  public void upgradeLevels() {
    PlatformTransactionManager transactionManager =
              new DataSourceTransActionManger(dataSource);

    TransactionStatus status = 
              transactionManager.getTransaction(new DefaultTransactionDefinition());

    try{
      userService.upgradeLevels();
      transactionManager.commit(status);
    }
    catch(Exception e){
      transactionManager.rollback(status);
      throw e;
    }
  }

}
~~~

<br>
이렇게 수정하면 UserService에는 처음에 트랜잭션을 고려하지 않고 단순하게 로직만을 구현했던 처음 모습으로 돌아왔다. 코드 어디에도 기술이나 서버환경에 관련된 코드는 보이지 않는다. 트랜잭션의 경계설정이라는 부가작업은 UserServiceTx 클래스에서 알아서 처리해준다.
