NEWPOST=$(HUGO) new post/
COMPILE_TIME_WIN = $(shell echo %date:~10,4%-%date:~4,2%-%date:~7,2%-)

all: new_post
pull:
		make submodule_update
		git pull
		hugo
force_update:
		git reset --hard origin/master
		git pull
		hugo
submodule_update:
		git submodule foreach git pull
		