import { fileURLToPath } from 'node:url';

import commonjs from '@rollup/plugin-commonjs';
import image from '@rollup/plugin-image';
import json from '@rollup/plugin-json';
import { nodeResolve } from '@rollup/plugin-node-resolve';
import replace from '@rollup/plugin-replace';
import typescript from '@rollup/plugin-typescript';
import { defineConfig } from 'rollup';
import del from 'rollup-plugin-delete';
import externalGlobals from 'rollup-plugin-external-globals';
import { visualizer } from 'rollup-plugin-visualizer';

const hiddenWarnings = ['THIS_IS_UNDEFINED', 'EVAL'];

const frontendConfig = (vite) => [
  // Main bundle
  {
    input: 'src/index.ts',
    plugins: [
      vite && {
        name: 'experimental-steam-vite-compat',
        resolveId(source, importer) {
          if (importer?.includes('@decky/ui/') && /(^|\/)Tabs$/.test(source)) {
            return fileURLToPath(new URL('./compat/vite-tabs.js', import.meta.url));
          }
          if (importer?.includes('@decky/ui/') && /(^|\/)Field$/.test(source)) {
            return fileURLToPath(new URL('./compat/vite-field.js', import.meta.url));
          }
          if (importer?.includes('@decky/ui/') && /(^|\/)Focusable$/.test(source)) {
            return fileURLToPath(new URL('./compat/vite-focusable.js', import.meta.url));
          }
          if (importer?.includes('@decky/ui/') && /(^|\/)static-classes$/.test(source)) {
            return fileURLToPath(new URL('./compat/vite-static-classes.js', import.meta.url));
          }
          if (importer?.includes('@decky/ui/') && /(^|\/)Panel$/.test(source)) {
            return fileURLToPath(new URL('./compat/vite-panel.js', import.meta.url));
          }
          if (
            source === '@decky/ui/dist/webpack' ||
            (importer?.includes('@decky/ui/') && /(^|\/)webpack$/.test(source))
          ) {
            return fileURLToPath(new URL('./compat/vite-webpack.js', import.meta.url));
          }
        },
        transform(code, id) {
          if (!id.includes('@decky/ui/') || !id.endsWith('.js')) return;
          // Rolldown uses template literals for static strings. Normalize only
          // discovery predicates, never Steam's functions or global prototypes.
          return {
            code: code
              .replace(/\.toString\?\.\(\)/g, '.toString?.()?.replaceAll("`", \'"\')')
              .replace(/\.toString\(\)/g, '.toString().replaceAll("`", \'"\')'),
            map: { mappings: '' },
          };
        },
      },
      del({
        targets: vite
          ? ['../backend/decky_loader/static/vite/*']
          : [
              '../backend/decky_loader/static/*',
              '!../backend/decky_loader/static/fallback.js',
              '!../backend/decky_loader/static/vite',
            ],
        force: true,
      }),
      commonjs(),
      nodeResolve({
        browser: true,
      }),
      externalGlobals({
        react: 'SP_REACT',
        'react/jsx-runtime': 'SP_JSX',
        'react-dom': 'SP_REACTDOM',
        // hack to shut up react-markdown
        process: '{cwd: () => {}}',
        path: '{dirname: () => {}, join: () => {}, basename: () => {}, extname: () => {}}',
        url: '{fileURLToPath: (f) => f}',
      }),
      typescript(),
      json(),
      replace({
        preventAssignment: false,
        'process.env.NODE_ENV': JSON.stringify('production'),
      }),
      image(),
      visualizer(),
    ],
    preserveEntrySignatures: false,
    treeshake: {
      // Assume all external modules have imports with side effects (the default) while allowing decky libraries to treeshake
      pureExternalImports: true,
      preset: 'smallest',
    },
    output: {
      dir: vite ? '../backend/decky_loader/static/vite' : '../backend/decky_loader/static',
      format: 'esm',
      chunkFileNames: (chunkInfo) => {
        return 'chunk-[hash].js';
      },
      sourcemap: true,
      sourcemapPathTransform: (relativeSourcePath) => relativeSourcePath.replace(/^\.\.\//, `decky://decky/loader/`),
    },
    onwarn: function (message, handleWarning) {
      if (hiddenWarnings.some((warning) => message.code === warning)) return;
      handleWarning(message);
    },
  },
  // Fallback
  ...(!vite
    ? [
        {
          input: 'src/fallback.ts',
          plugins: [typescript()],
          output: {
            file: '../backend/decky_loader/static/fallback.js',
            format: 'esm',
          },
        },
      ]
    : []),
];

// Ship both variants in the same release artifact. The backend selects one
// against the target Steam client, not the machine compiling Decky.
export default defineConfig([...frontendConfig(false), ...frontendConfig(true)]);
