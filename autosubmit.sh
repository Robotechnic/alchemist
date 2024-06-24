#! /usr/bin/sh

version="0.1.0"
path=$PWD

eval "$(ssh-agent -s)" 

cd ..

if [ ! -d "packages" ]; then
	git clone git@github.com:Robotechnic/packages.git
else
	cd packages
	git pull origin main
fi

cd $path

package_path="../packages/packages/preview/alchemist/$version"
if [ -d $package_path ]; then
	rm -rf $package_path
fi

mkdir -p $package_path
make module
cp -f ./alchemist/* $package_path/
rm -rf ./alchemist


cd ../packages
git add "./packages/preview/alchemist/$version/*"

# if a message is provided, use it, otherwise use the default
message="Upload alchemist v$version"
if [ $# -eq 1 ]; then
	message=$1
fi

git commit -am "$message"
git push