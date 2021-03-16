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

![image](https://user-images.githubusercontent.com/7456710/111270713-8c693c00-8673-11eb-84df-f767ac801256.png)

<br>
Client와 UserService 구현 클래스들의 의존관계를 표현하면 위의 그림과 같다. 이렇게 트랜잭션 경계설정 코드의 분리와 DI를 통한 연결을 하게되면 다음과 같은 장점을 얻는다.  
+ 비즈니스 로직을 담당하고 있는 UserServiceImpl의 코드를 작성할 때는 트랜잭션과 같은 기술적인 내용에는 전혀 신경 쓰지 않아도 된다. 트랜잭션의 적용이 필요한지도 신경 쓰지 않아도 된다. 따라서 언제든지 트랜잭션 기능을 도입할 수 있다.  
+ 비즈니스 로직에 대한 테스트를 손쉽게 만들어 낼 수 있다.  


### 고립된 단위 테스트
가장 편하고 좋은 테스트 방법은 가능한 작은 단위로 쪼개서 테스트하는 것이다. 작은 단위의 테스트가 좋은 이유는 테스트가 실패했을 때 그 원인을 찾기 쉽기 때문이다. 반대로 테스트에서 오류가 발견됐을 때 그 테스트가 진행되는 동안 실행된 코드의 양이 많다면 그 원인을 찾기가 매우 힘들어질 수도 있다.  
우리가 만든 UserService의 테스트를 만든다고 생각해보자. UserService는 간단한 기능만 가지고 있지만 여러 타입의 의존 오브젝트가 필요하다. 따라서 UserService의 기능이 잘 작동하는지 전체적인 기능을 테스트 한다면 UserService를 테스트하는 것처럼 보이지만 사실은 그 뒤에 존재하는 훨씬 더 많은 오브젝트와 환경, 서비스, 서버, 심지어 네트워크까지 함께 테스트 하는 셈이 된다. 그 중 하나라도 문제를 일으킨다면 UserService에 대한 테스트가 실패한다. 그래서 UserService라는 테스트 대상이 단위 테스트인 것처럼 보이지만 사실은 그 뒤의 의존관계를 따라 등장하는 오브젝트와 서비스, 환경 등이 모두 합쳐서 테스트 대상이 되는 것이다.  
막상 UserService는 간단한 동작을 하는데 뒤에 숨겨진 오브젝트들이 복잡한 기능을 한다면 배보다 배꼽이 더 큰 작업이 되버린다.  
<br>
그래서 테스트의 대상이 환경이나 외부 서버, 다른 클래스의 코드에 종속되고 영향을 받지 않도록 고립시킬 필요가 있다. 우리가 사용할 수 있는 방법은 mock 오브젝트를 만들어 UserServiceImpl이 mock 오브젝트를 가르키도록 하는것이다.  
<br>

~~~java
static class MockUserDao implements UserDAO{
  private List<User> users;                           // 레벨 업그레이드 후보 User 오브젝트 목록
  private List<User> updatedUsers = new ArrayList();   // 업그레이드 대상 오브젝트를 저장해둘 목록
  
  public MockUserDao(List<User> users){
    this.users = users;
  }
  
  public List<User> getUpdatedUsers(){
    return this.updatedUsers;
  }
  
  public List<User> getAll(){
    return this.users;
  }
  
  public void update(User user){
    updatedUsers.add(user);
  }
  
  public void add(User user) { throw new UnsupportedOperationException(); }
  public void deleteAll() { throw new UnsupportedOperationException(); }
  
}
~~~
<br>
MockUserDao는 UserDao 인터페이스를 구현해야하기 때문에 테스트에 사용하지 않는 메소드도 모두 만들어줘야하는 부담이 있다. 그냥 빈 채로 두거나 null을 반환해도 되지만 실수로 사용될 위험이 있으므로 지원하지 않는 기능이라는 예외를 발생하도록 만드는 것이 좋다. MockUserDao는 두 개의 User 타입 List를 정의해둔다. 하나는 생성자를 통해 전달받은 사용자 목록을 저장했뒀다가, getAll() 메소드가 호출되면 DB에서 가져온 것처럼 돌려주는 용도다. 다른 하나는 update(User user) 메소드를 실행하면 넘겨준 대상 User 오브젝트를 저장해뒀다가 검증을 위해 돌려주기 위한 것이다. 이 방법을 사용하면 일일히 DB에 저장했다가 다시 가져올 필요 없이 메모리에서 가지고 있다가 돌려주기만 하면 된다. 다음은 테스트 코드를 보자.
<br>

~~~java

@Test
public void upgradeLevels() throws Exception {
  UserServiceImpl userServiceImpl = new UserServiceImpl();
  
  MockUserDao mockUserDao = new MockUserDao(this.users);
  userServiceImpl.setUserDao(mockUserDao);
  
  userServiceImpl.upgradeLevels();
  
  List<User> updatedUsers = mockUserDao.getUpdatedUsers();
  assertThat(updatedUsers.size(),is(2));
  checkUserAndLevel(updatedUsers.get(0), "두 번째 사용자",LEVEL.SILVER);
  checkUserAndLevel(updatedUsers.get(0), "네 번째 사용자",LEVEL.GOLD);
}

public void checkUserAndLevel(User updatedUser, String expectedId, Level expectedLevel) {
    assertThat(updated.getId(), is(expectedId));
    assertThat(updated.getLevel(), is(expectedLevel));
}
~~~

<br>

이렇게 테스트 코드를 작성하면 DB에 영향을 안줄뿐만 아니라 테스트 수행 시간도 비약적으로 줄어든다. 고립된 테스트를 만들려면 목 오브젝트 작성과 같은 약간의 수고가 들지만 그 보상은 충분히 기대할 만하다.  
<br>
### 단위테스트와 통합 테스트
단위 테스트의 단위는 정하기 나름이다. 기능 전체를 하나의 단위로 볼 수 있고 하나의 클래스나 메소드를 단위로 볼 수도 있다. 토비의 스프링에서는 '테스트 대상 클래스를 목 오브젝트 등의 테스트 대역을 이용해 의존 오브젝트나 외부의 리소스를 사용하지 않도록 고립시켜서 테스트 하는 것'을 **단위 테스트**라 부르고 두개 이상의 성격이나 계층이 다른 오브젝트가 연동하도록 만들어 테스트하거나, 외부의 DB나 파일, 서비스 등의 리소스가 참여하는 테스트를 통합 테스트라고 부르기로 했다. 또, 단위 테스트와 통합 테스트 중에서 어떤 방법을 쓰면 좋을지 다음과 같은 가이드 라인을 제시해준다.  
+ 항상 단위 테스트를 먼저 고려한다.  
+ 하나의 클래스나 성격과 목적이 같은 긴밀한 클래스 몇 개를 모아서 외부와의 의존관계를 모두 차단하고 필요에 따라 스텁이나 목 오브젝트 등의 테스트 대역을 이용하도록 테스트를 만든다.  
  -> 단위 테스트는 테스트 작성도 간단하고 실행 속도도 빠르며 테스트 대상 외의 코드나 환경으로부터 테스트 결과에 영향을 받지 않기 때문에 가장 빠른 시간에 효과적인 테스트를 작성하기에 유리하다.  
+ 외부 리소스를 사용해야만 가능한 테스트는 통합 테스트로 만든다.  
  + DAO는 단위 테스트로 만들기 어려운 코드다. DAO는 그 자체로 로직을 담고 있기 보다는 DB를 통해 로직을 수행하는 인터페이스와 같은 역할을 하기 때문에 외부 리소스 사용이 불가피하다.  
+ 여러 개의 단위가 의존관계를 가지고 동작할 때를 위한 통합 테스트는 필요하다. 다만, 단위 테스트를 충분히 거쳤다면 통합 테스트의 부담은 상대적으로 줄어든다.  
+ 단위 테스트를 만들기가 너무 복잡하다고 판단되는 코드는 처음부터 통합 테스트를 고려해본다. 이때도 통합 테스트에 참여하는 코드 중 가능한 많은 부분을 단위 테스트로 검증해두는게 유리하다.  
+ 스프링 테스트 컨텍스트 프레임워크를 이용하는 테스트는 통합 테스트다. 가능하면 스프링의 지원 없이 코드 레벨에서 직접 DI를 사용하면서 단위 테스트를 하는 것이 좋지만 스프링 설정 자체도 테스트 대상이고, 스프링을 이용해 좀 더 추상적인 레벨에서 테스트해야 할 경우도 있다.  
<br>

단위 테스트를 만들기 위해서 스텁이나 목 오브젝트의 사용이 필수적이다. 의존 관계가 없는 단순한 클래스나 세부 로직을 검증하기 위해 메소드 단위로 테스트할 때가 아니라면, 대부분 의존 오브젝트를 필요로 하는 코드를 테스트하게 되기 때문이다. 하지만 매번 목 오브젝트를 만드는 일은 번거롭다. 다행히 이런 목 오브젝트를 편리하게 작성하도록 도와주는 목 오브젝트 지원 프레임워크가 있다.  
<br>

### Mockito 프레임워크
Mockito 프레임워크가 그 중 하나다. Mockito 프레임워크를 사용하면 UserDAO 인터페이스를 구현한 클래스를 만들 필요도 없고 일일히 기능들을 작성할 필요도 없다. Mockito의 Mock 오브젝트는 다음의 단계를 거쳐서 사용하면 된다.  
+ 인터페이스를 이용해 목 오브젝트를 만든다.  
+ 목 오브젝트가 리턴할 값이 있으면 이를 지정해준다. 예외를 강제로 던지게 만들 수도 있다.  
+ 테스트 대상 오브젝트에 DI해서 목 오브젝트가 테스트 중에 사용되도록 만든다.  
+ 테스트 대상 오브젝트를 사용한 후에 목 오브젝트의 특정 메소드가 호출 됐는지, 어떤 값을 가지고 몇번 호출됐는지를 검증한다.  

<br>

~~~java

@Test
public void upgradeLevels() throws Exception {
  UserServiceImpl userServiceImpl = new UserServiceImpl();
  
  UserDao mockUserDao = mock(UserDAO.class);
  when(mockUserDao.getAll()).thenReturn(this.users);
  userServiceImpl.setUserDao(mockUserDao);
  
  userServiceImpl.upgradeLevels();
  
  verify(mockUserDao, times2)).update(any(User.class));
  verify(mockUserDao).update(users.get(1)); // 두 번째 사용자가 업데이트 됐는지 검사
  assertThat(users.get(1).getLevel()), is(Level.SILVER));
  verify(mockUserDao).update(users.get(3)); // 네 번째 사용자가 업데이트 됐는지 검사
  assertThat(users.get(3).getLevel()), is(Level.GOLD));
}
~~~

<br>
이렇게 Mockito를 사용하면 Mock 오브젝트를 위한 구현체를 따로 만들 필요없이 편하게 테스트 코드를 작성할 수 있다.
