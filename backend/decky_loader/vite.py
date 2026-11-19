"""Prepare the live Steam Vite module cache before loading the bundled frontend."""

from asyncio import sleep, timeout
from logging import getLogger

from .injector import Tab

logger = getLogger('Vite')


async def prepare_frontend(tab: Tab) -> str:
    """Return a bundled entry point, retaining the original Webpack path."""
    async def call(method, **params):
        async with timeout(45):
            response = await tab._send_devtools_cmd({'method': method, 'params': params})
        if response is None or 'error' in response:
            raise RuntimeError(f'Steam debugger command failed: {method}')
        result = response['result']
        if 'exceptionDetails' in result:
            raise RuntimeError(f'Steam evaluation failed: {result["exceptionDetails"]}')
        return result

    async def evaluate(expression, **params):
        return await call('Runtime.evaluate', expression=expression, **params)

    async def properties(object_id):
        return await call('Runtime.getProperties', objectId=object_id, ownProperties=True)

    # Steam may expose its debugger before its module runtime has initialized.
    async with timeout(90):
        while True:
            state = (await evaluate('''({
              webpack: !!window.webpackChunksteamui,
              ready: window.App?.BFinishedInitBeforeLogin?.() ?? window.App?.BFinishedInitStageOne?.() ?? false
            })''', returnByValue=True))['result']['value']
            if state['webpack']:
                return 'index.js'
            if state['ready']:
                break
            await sleep(0.25)

    result = await evaluate('''(async () => {
      const urls = [...new Set(performance.getEntriesByType('resource')
        .map(e => e.name).filter(url => {
          const u = new URL(url);
          return u.origin === location.origin && /^\\/chunk[^/]*\\.js$/.test(u.pathname);
        }))];
      for (const url of urls) {
        const source = await fetch(url).then(r => r.text());
        if (!source.includes('QuickAccessMenuBrowserView')) continue;
        const namespace = await import(url);
        return Object.values(namespace).filter(value => typeof value === 'function'
          && !value.toString().includes('t.exports'));
      }
      throw new Error('Cannot locate Steam QAM module');
    })()''', awaitPromise=True)
    functions = await properties(result['result']['objectId'])
    bindings = None
    for item in functions['result']:
        function = item.get('value', {})
        if function.get('type') != 'function':
            continue
        details = await properties(function['objectId'])
        scopes = next((p['value']['objectId'] for p in details.get('internalProperties', [])
                       if p['name'] == '[[Scopes]]'), None)
        if not scopes:
            continue
        for scope in (await properties(scopes))['result']:
            value = scope.get('value', {})
            if value.get('description') == 'Module':
                candidate = (await properties(value['objectId']))['result']
                if len(candidate) > 1000:
                    bindings = candidate
                    break
        if bindings:
            break
    if not bindings:
        raise RuntimeError('Cannot inspect Steam QAM module scope')

    cache = await evaluate('window.__DECKY_VITE_MODULES = new Map()')
    usable = [b for b in bindings if b.get('value', {}).get('objectId')
              or b.get('value', {}).get('type') in ('string', 'number', 'boolean')]
    for start in range(0, len(usable), 100):
        batch = usable[start:start + 100]
        arguments = [({'objectId': b['value']['objectId']} if b['value'].get('objectId')
                      else {'value': b['value'].get('value')}) for b in batch]
        arguments.append({'value': [b['name'] for b in batch]})
        await call('Runtime.callFunctionOn', objectId=cache['result']['objectId'],
                   functionDeclaration='''function(...args) {
                     const names=args.pop();
                     args.forEach((value,i)=>{if(value!=null)this.set(names[i],value)});
                   }''', arguments=arguments)
    logger.info('Prepared Vite frontend (%d Steam bindings)', len(usable))
    return 'vite/index.js'
