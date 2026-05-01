.PHONY: test app run clean

test:
	./scripts/test.sh

app:
	./scripts/build-app.sh

run: app
	open .build/TodoDesk.app

clean:
	rm -rf .build
