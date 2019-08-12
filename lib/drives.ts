import axios from 'axios'
import * as fs from 'fs'

export async function meDrive(root: string, token: string) {
    const headers = {
        Authorization: 'bearer ' + token
    }
    const resp = await axios.get(root + '/me/drive', { headers })
    return resp.data
}

interface Item {
    id: string
    name: string
    webUrl: string
    size: number
    folder?: {
        childCount: number
    }
    file?: {
        mimeType: string
    }
}

export async function itemList(root: string, token: string, path: string) {
    const headers = {
        Authorization: 'bearer ' + token
    }
    if (path.length > 1) {
        path = `:/${path}:/`
    }
    const resp = await axios.get<{ value: Item[] }>(root + '/me/drive/root' + path + 'children', { headers })
    return resp.data.value
}

export async function itemInfo(root: string, token: string, id: string) {
    const headers = {
        Authorization: 'bearer ' + token
    }
    id = encodeURIComponent(id)
    const resp = await axios.get<Item>(root + '/me/drive/items/' + id, { headers })
    if (!resp.data.folder) {
        const cont = await axios.get<Item>(root + '/me/drive/items/' + id + '/content', { headers, maxRedirects: 0, validateStatus: i => i < 400 })
        resp.data.webUrl = cont.headers['location']
    }
    return resp.data
}

export async function uploadSession(root: string, token: string, path: string) {
    const headers = {
        Authorization: 'bearer ' + token
    }
    path = `:/${encodeURIComponent(path)}:`
    const resp = await axios.post<{ uploadUrl: string, expirationDateTime: string }>(root + '/me/drive/root' + path + '/createUploadSession', {}, { headers })
    return resp.data
}

const SIZE_4M = 4 * 1024 * 1024

export async function uploadIter(url: string, fd: number, total: number) {
    let data = Buffer.alloc(SIZE_4M)
    let nx = 0
    let sum = 0
    do {
        nx = fs.readSync(fd, data, 0, SIZE_4M, sum)
        const headers = {
            'Content-Length': nx,
            'Content-Range': `bytes ${sum}-${sum + nx - 1}/${total}`
        }
        sum += nx
        console.log({ nx, sum, headers })
        const end = nx < SIZE_4M
        if (end) {
            data = data.slice(0, nx)
        }
        const resp = await axios.put(url, data, { headers })
        console.log(resp.data)
        if (end) {
            return
        }
    } while (nx > 0)
}
