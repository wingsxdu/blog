HUGO=hugo
NEWPOST=$(HUGO) new post/
COMPILE_TIME_WIN = $(shell echo %date:~10,4%-%date:~4,2%-%date:~7,2%-)
msg=commit
GIT_ADD = git add .
GIT_COMMIT = git commit -m "$(msg)"
GIT_Push = git push
all: new_post
new_post:
		$(NEWPOST)$(msg)
push:
		$(GIT_ADD) 
		$(GIT_COMMIT) 
		$(GIT_Push)
pull:
		git pull
		rm -rf public
		$(HUGO) 
update:
		git submodule foreach 'git checkout -f' 

web:
		hugo new --kind web post/build-web-application-with-golang/$(msg)