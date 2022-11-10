virtualenv:
	LC_ALL=en_US.UTF-8 python3 -m venv ./virtualenv
	. ./virtualenv/bin/activate
	./virtualenv/bin/pip install pip --upgrade
	LC_ALL=en_US.UTF-8 ./virtualenv/bin/pip3 install -r requirements.txt

preview:
  . ./virtualenv/bin/activate
  mkdocs gh-deploy -m "Update GitHub pages for latest documentation release" -b gh-pages --force -v
