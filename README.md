onedrive-cli
-------------------------------------------
利用[api](https://dev.onedrive.com/getting-started.htm)方便在服务器上传下载

## 获取token

`odrive-cli auth --client_id 0f207c76-5a22-4f74-9e47-ee2c038f3a70 --client_secret 9e0U23VomDjwj4pS3Rg1MKq`

## show list

`odrive-cli show list -p somepath'

## upload
`odrive-cli put somelocalpath --size 20 -p Movies/`

## download

`odrive-cli get itemid -o somelocalpath`

