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
    const resp = await axios.get<{value: Item[]}>(root + '/me/drive/root' + path + 'children', { headers })
    return resp.data.value
}

export async function dirs(root: string, token: string, path?: string) {

}
