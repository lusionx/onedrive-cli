
import axios from 'axios'
import * as Qs from 'querystring'
import * as fs from 'fs'
import moment from 'moment'


export function AuthUrl(client_id: string, scope: string) {
    const open = [
        "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?",
        `client_id=${client_id}&`,
        `scope=${encodeURIComponent(scope)}&`,
        "response_type=code&",
        `redirect_uri=${encodeURIComponent(redirect_uri)}`,
    ].join('')
    console.log('open', open)
    return open
}

export interface Info {
    access_token: string
    refresh_token: string
    expires_in: number
    expires_at: number
    client_id: string
    client_secret: string
}

const INFO_PATH = process.env['HOME'] + '/.odInfo.json'
const redirect_uri = 'http://localhost:44321'

export async function exToken(code: string, client_id: string, client_secret: string) {
    const params = {
        code, client_secret, client_id, redirect_uri,
        grant_type: 'authorization_code',
    }
    const resp = await axios.post<Info>('https://login.microsoftonline.com/common/oauth2/v2.0/token', Qs.stringify(params))
    resp.data.client_id = client_id
    resp.data.client_secret = client_secret
    resp.data.expires_at = resp.data.expires_in + moment().unix()
    console.log(resp.data, INFO_PATH)
    fs.writeFile(INFO_PATH, JSON.stringify(resp.data), err => err)
    return resp.data
}

export async function getToken() {
    const bf: Buffer = fs.readFileSync(INFO_PATH)
    const info: Info = JSON.parse(bf.toString())
    if (info.expires_at > moment().unix()) {
        return info
    }
    const params = {
        client_id: info.client_id,
        client_secret: info.client_secret,
        grant_type: 'refresh_token',
        redirect_uri: redirect_uri,
        refresh_token: info.refresh_token,
    }
    const resp = await axios.post<Info>('https://login.microsoftonline.com/common/oauth2/v2.0/token', Qs.stringify(params))
    resp.data.expires_at = resp.data.expires_in + moment().unix()
    Object.assign(info, resp.data)
    fs.writeFile(INFO_PATH, JSON.stringify(info), err => err)
    return info
}

export function fsStat(path: string): Promise<fs.Stats | undefined> {
    return new Promise<fs.Stats>((res, rej) => {
        fs.access(path, (err) => {
            if (err) {
                return res()
            }
            fs.stat(path, (err, st) => {
                err ? rej(err) : res(st)
            })
        })
    })
}
