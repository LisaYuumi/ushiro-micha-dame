"""オンライン対戦の「相手を見つける」役に使えそうな無料サービスを、実際に試す。
1. PeerJS 公開サーバー: 2人が入って、片方からもう片方へメッセージが届くか
2. ntfy.sh: WebSocket で待ち受けて、HTTP で送ったメッセージが届くか(ブラウザから使えるか=CORS も見る)"""
import asyncio, json, random, urllib.request
import websockets


async def recv_json(ws, timeout=10):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout))


async def check_peerjs():
    tmpl = "wss://0.peerjs.com/peerjs?key=peerjs&id={id}&token={tok}"
    ok = 0
    for attempt in range(5):
        host_id = "ushiromichadame-%04d" % random.randint(0, 9999)
        guest_id = "ushiromichadame-guest-%d" % random.randint(0, 10**9)
        try:
            async with websockets.connect(tmpl.format(id=host_id, tok=random.randint(0, 10**9))) as host:
                await recv_json(host)
                async with websockets.connect(tmpl.format(id=guest_id, tok=random.randint(0, 10**9))) as guest:
                    await recv_json(guest)
                    await guest.send(json.dumps({"type": "OFFER", "dst": host_id, "payload": {"sdp": "x", "type": "data", "connectionId": "dc_1"}}))
                    m = await recv_json(host, 6)
                    print("  peerjs relay OK:", m.get("type"))
                    ok += 1
        except Exception as e:
            print("  peerjs relay failed:", repr(e))
    print("PEERJS relayed %d/5" % ok)


async def check_ntfy():
    topic = "ushiromichadame-test-%d" % random.randint(0, 10**9)
    async with websockets.connect("wss://ntfy.sh/%s/ws" % topic) as ws:
        print("  ntfy first:", (await recv_json(ws)).get("event"))
        req = urllib.request.Request("https://ntfy.sh/%s" % topic, data=("x" * 3000).encode(), method="POST",
                                     headers={"Origin": "https://lisayuumi.github.io"})
        with urllib.request.urlopen(req, timeout=10) as r:
            print("  ntfy POST:", r.status, "CORS:", r.headers.get("Access-Control-Allow-Origin"))
        m = await recv_json(ws)
        print("  ntfy received event:", m.get("event"), "len:", len(m.get("message", "")))
    print("NTFY OK")


async def main():
    print("== PeerJS")
    await check_peerjs()
    print("== ntfy.sh")
    try:
        await check_ntfy()
    except Exception as e:
        print("NTFY failed:", repr(e))


asyncio.run(main())
