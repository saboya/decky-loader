import importlib.util
from pathlib import Path
import sys
import types
import unittest
from typing import Any


# Load the helper without importing Decky's application and platform services.
def load_helper() -> types.ModuleType:
    package = types.ModuleType('_vite_test')
    package.__path__ = []
    injector = types.ModuleType('_vite_test.injector')
    setattr(injector, 'Tab', object)
    sys.modules[package.__name__] = package
    sys.modules[injector.__name__] = injector
    spec = importlib.util.spec_from_file_location(
        '_vite_test.vite', Path(__file__).parents[1] / 'decky_loader/vite.py')
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


helper = load_helper()


class FakeTab:
    def __init__(self, webpack: bool = False, failure: bool = False):
        self.webpack = webpack
        self.failure = failure
        self.commands: list[dict[str, Any]] = []

    async def send_devtools_command(self, method: str, **params: Any) -> dict[str, Any]:
        command = {'method': method, 'params': params}
        self.commands.append(command)
        if self.failure:
            return {'error': {'message': 'Disconnected'}}
        if method == 'Runtime.evaluate':
            expression = params['expression']
            if 'webpack:' in expression:
                return {'result': {'result': {'value': {'webpack': self.webpack, 'ready': True}}}}
            object_id = 'cache' if 'new Map()' in expression else 'functions'
            return {'result': {'result': {'objectId': object_id}}}
        if method == 'Runtime.getProperties':
            object_id = params['objectId']
            if object_id == 'functions':
                result: dict[str, Any] = {'result': [{'value': {'type': 'function', 'objectId': 'function'}}]}
            elif object_id == 'function':
                result = {'internalProperties': [{'name': '[[Scopes]]', 'value': {'objectId': 'scopes'}}]}
            elif object_id == 'scopes':
                result = {'result': [{'value': {'description': 'Module', 'objectId': 'module'}}]}
            else:
                result = {'result': [{'name': str(i), 'value': {'type': 'string', 'value': 'css'}}
                                     for i in range(1001)]}
            return {'result': result}
        return {'result': {}}


class FrontendSelectionTests(unittest.IsolatedAsyncioTestCase):
    async def test_webpack_uses_original_frontend_without_module_inspection(self):
        tab = FakeTab(webpack=True)
        self.assertEqual(await helper.prepare_frontend(tab), 'index.js')
        self.assertEqual(len(tab.commands), 1)

    async def test_vite_populates_cache_and_selects_bundled_frontend(self):
        tab = FakeTab()
        self.assertEqual(await helper.prepare_frontend(tab), 'vite/index.js')
        transfers = [c for c in tab.commands if c['method'] == 'Runtime.callFunctionOn']
        self.assertEqual(len(transfers), 11)
        self.assertEqual(transfers[0]['params']['arguments'][0], {'value': 'css'})

    async def test_debugger_failure_is_not_mistaken_for_webpack(self):
        with self.assertRaises(RuntimeError):
            await helper.prepare_frontend(FakeTab(failure=True))
