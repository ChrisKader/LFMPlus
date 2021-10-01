rm .\addon\ -r -fo
mkdir .\addon\LFM+
mkdir .\addon\LFM+\locale
Copy-Item -Path ".\*" -Include *.lua, *.xml, *.toc -Destination ".\addon\LFM+\"
Copy-Item -Path ".\locale\*" -Include *.lua -Destination ".\addon\LFM+\locale\"
Copy-Item .\libs addon\LFM+\libs -Recurse
Compress-Archive .\addon\LFM+\ .\release\LFM+.zip -Force
rm .\addon\ -r -fo