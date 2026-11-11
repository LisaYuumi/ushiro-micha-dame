"""PeerJS の公開サーバーに、ゲーム(scripts/net/net_session.gd)と同じ URL でつなげるか確かめる。
ホスト役と参加者役の2つでつなぎ、参加者からホストへ OFFER が届くかまで見る。"""
import asyncio, json, random, urllib.request
import websockets

URLS = [
    "wss://0.peerjs.com/peerjs?key=peerjs&id={id}&token={tok}",
    "wss://0.peerjs.com/peerjs?key=peerjs&id={id}&token={tok}&version=1.5.4",
]


async def first_message(ws, timeout=10):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout))


async def try_url(tmpl):
    code = "%04d" % random.randint(0, 9999)
    host_id = "ushiromichadame-" + code
    guest_id = "ushiromichadame-guest-%d" % random.randint(0, 10**9)
    print("URL:", tmpl)
    async with websockets.connect(tmpl.format(id=host_id, tok=random.randint(0, 10**9))) as host:
        print("  host first message:", await first_message(host))
        async with websockets.connect(tmpl.format(id=guest_id, tok=random.randint(0, 10**9))) as guest:
            print("  guest first message:", await first_message(guest))
            await guest.send(json.dumps({"type": "OFFER", "dst": host_id, "payload": {"sdp": "test", "godot_id": 5}}))
            print("  host received:", await first_message(host))


async def main():
    try:
        with urllib.request.urlopen("https://0.peerjs.com/peerjs/id", timeout=10) as r:
            print("GET /peerjs/id ->", r.status, r.read()[:60])
    except Exception as e:
        print("GET /peerjs/id failed:", e)
    for t in URLS:
        try:
            await try_url(t)
        except Exception as e:
            print("  FAILED:", repr(e))


asyncio.run(main())
