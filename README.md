# onedrive-cli
利用方便在服务器上传下载

## 获取token

`odrive-cli auth --client_id xxxxx --client_secret yyyyy`

[api](https://dev.onedrive.com/getting-started.htm), creat your app from [doc](https://dev.onedrive.com/app-registration.htm)

## show list

`odrive-cli show list -p somepath`

## upload
`odrive-cli put somelocalpath --size 20 -p Movies/`

## download

`odrive-cli get itemid -o somelocalpath`

