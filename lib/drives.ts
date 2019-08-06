import axios from 'axios'

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

export async function dirs(root: string, token: string, path?: string) {

}
