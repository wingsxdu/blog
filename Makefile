HUGO=hugo
NEWPOST=$(HUGO) new post/
COMPILE_TIME_WIN = $(shell echo %date:~10,4%-%date:~4,2%-%date:~7,2%-)
title=newPost
msg=commit
GIT_ADD = git add .
GIT_COMMIT = git commit -m "$(msg)"
GIT_Push = git push
all: new_post
new_post:
		$(NEWPOST)$(COMPILE_TIME_WIN)$(title).md
push:
		$(HUGO) 
		$(GIT_ADD) 
		$(GIT_COMMIT) 
		$(GIT_Push)
		cd public && make push