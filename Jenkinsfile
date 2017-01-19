node("slave"){
  stage 'checkout'
  git 'https://github.com/929121806/test1.git'

  stage 'create service'
  sh 'chmod a+x ./service.sh'
  sh './service.sh' 

  stage 'run project'
  sh 'python ./main.py'

  stage 'ci test'
  sh 'python ./test.py'
}
