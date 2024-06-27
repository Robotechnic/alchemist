link :
	mkdir -p ~/.cache/typst/packages/preview/alchemist
	ln -s "$(CURDIR)" ~/.cache/typst/packages/preview/alchemist/0.1.0

clean-link:
	rm -rf ~/.cache/typst/packages/preview/alchemist

module:
	sh ./generate_images.sh
	mkdir -p ./alchemist
	mkdir -p ./alchemist/src
	cp ./typst.toml ./alchemist/typst.toml
	cp ./LICENSE ./alchemist/LICENSE
	cp ./*.typ ./alchemist/
	cp ./src/*.typ ./alchemist/src/
	awk '/<!--EXCLUDE-->/, /<!--END-->/ {next} 1' ./README.md > ./alchemist/README.md