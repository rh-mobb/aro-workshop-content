virtualenv:
	LC_ALL=en_US.UTF-8 python3 -m venv ./virtualenv
	. ./virtualenv/bin/activate
	./virtualenv/bin/pip install pip --upgrade
	LC_ALL=en_US.UTF-8 ./virtualenv/bin/pip3 install -r requirements.txt

.PHONY: preview
preview: virtualenv
	./virtualenv/bin/mkdocs serve

.PHONY: gh-pages
gh-pages: virtualenv
	./virtualenv/bin/mkdocs gh-deploy -m "Manual update of gh-pages" -b gh-pages --force -v

.PHONY: deploy
deploy:
	./hack/build-on-openshift.sh

.PHONY: destroy
destroy:
	oc delete project workshop

