HUGO=hugo
NEWPOST=$(HUGO) new post/
COMPILE_TIME_WIN = $(shell echo %date:~10,4%-%date:~4,2%-%date:~7,2%-)
title=newPost
all: new_post
new_post:
		$(NEWPOST)$(COMPILE_TIME_WIN)$(title).md