import { Hono } from "hono";
import { cors } from "hono/cors";
import { createHash } from "node:crypto";

/**
 * Slang Cloud Server - Hono Implementation
 *
 * Features:
 * - HEAD/GET /translations/:locale - For slang_cloud client
 * - Full CRUD for languages
 * - Translation management (full replace, patch, nested updates)
 * - In-memory storage with auto hash calculation
 * - CORS enabled for Flutter web testing
 * - Vue.js 3 Admin Panel at /admin
 */

// Types
interface Language {
  code: string;
  name: string;
  nativeName?: string;
  translations: Record<string, any>;
  hash: string;
  createdAt: Date;
  updatedAt: Date;
}

interface CreateLanguageRequest {
  code: string;
  name: string;
  nativeName?: string;
  translations?: Record<string, any>;
}

interface UpdateTranslationsRequest {
  translations: Record<string, any>;
}

// In-memory database
const database = new Map<string, Language>();

// Helper functions
function calculateHash(translations: Record<string, any>): string {
  return createHash("md5").update(JSON.stringify(translations)).digest("hex");
}

function validateTranslations(data: any): Record<string, any> {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new Error("Translations must be a valid JSON object");
  }
  return data;
}

function deepMerge(target: any, source: any): any {
  if (typeof target !== "object" || target === null) return source;
  if (typeof source !== "object" || source === null) return target;

  const result = { ...target };
  for (const key in source) {
    if (source.hasOwnProperty(key)) {
      if (
        typeof source[key] === "object" &&
        source[key] !== null &&
        !Array.isArray(source[key])
      ) {
        result[key] = deepMerge(result[key], source[key]);
      } else {
        result[key] = source[key];
      }
    }
  }
  return result;
}

function createLanguage(data: CreateLanguageRequest): Language {
  const translations = data.translations || {};
  const now = new Date();
  return {
    code: data.code,
    name: data.name,
    nativeName: data.nativeName,
    translations: validateTranslations(translations),
    hash: calculateHash(translations),
    createdAt: now,
    updatedAt: now,
  };
}

// Seed data
function seedDatabase() {
  const seedLanguages: CreateLanguageRequest[] = [
    {
      code: "en",
      name: "English",
      nativeName: "English",
      translations: {
        main: {
          title: "Slang Cloud Demo (Server)",
          description: "This text is served from the Hono backend!",
          button: "Check for Updates",
        },
      },
    },
    {
      code: "de",
      name: "German",
      nativeName: "Deutsch",
      translations: {
        main: {
          title: "Slang Cloud Demo (Server DE)",
          description: "Dieser Text kommt vom Hono Backend!",
          button: "Nach Updates suchen",
        },
        common: {
          version: "tor nani",
        },
      },
    },
  ];

  seedLanguages.forEach((lang) => {
    database.set(lang.code, createLanguage(lang));
  });

  console.log(`✅ Seeded ${seedLanguages.length} languages`);
}

// Initialize app
const app = new Hono();

// Middleware
app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "X-Translation-Hash"],
  })
);

// Admin Panel HTML
const adminHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Slang Cloud Admin</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
    [v-cloak] { display: none; }
    .fade-enter-active, .fade-leave-active { transition: opacity 0.3s; }
    .fade-enter-from, .fade-leave-to { opacity: 0; }
    .slide-enter-active, .slide-leave-active { transition: transform 0.3s; }
    .slide-enter-from { transform: translateX(100%); }
    .slide-leave-to { transform: translateX(100%); }
    .btn-primary {
      @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors;
    }
    .btn-secondary {
      @apply px-4 py-2 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 transition-colors;
    }
    .btn-danger {
      @apply px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors;
    }
  </style>
</head>
<body class="bg-gray-100">
  <div id="app" v-cloak>
    <div class="min-h-screen flex">
      <!-- Sidebar -->
      <aside class="w-80 bg-white shadow-lg flex flex-col">
        <div class="p-6 border-b bg-gradient-to-r from-blue-600 to-blue-700">
          <h1 class="text-2xl font-bold text-white flex items-center gap-2">
            <i class="fas fa-globe"></i>
            Slang Cloud
          </h1>
          <p class="text-blue-100 text-sm mt-1">Translation Admin</p>
        </div>
        
        <div class="p-4 border-b">
          <button @click="showAddModal = true" class="btn-primary w-full flex items-center justify-center gap-2">
            <i class="fas fa-plus"></i>
            Add Language
          </button>
        </div>
        
        <div class="p-4">
          <div class="relative">
            <i class="fas fa-search absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"></i>
            <input 
              v-model="searchQuery" 
              placeholder="Search languages..."
              class="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            />
          </div>
        </div>
        
        <nav class="flex-1 overflow-auto p-2">
          <div
            v-for="lang in filteredLanguages"
            :key="lang.code"
            @click="selectLanguage(lang)"
            :class="{ 
              'bg-blue-50 border-blue-200': selectedLanguage?.code === lang.code,
              'hover:bg-gray-50': selectedLanguage?.code !== lang.code
            }"
            class="p-3 rounded-lg cursor-pointer border border-transparent mb-1 transition-all"
          >
            <div class="flex items-center gap-3">
              <span class="text-2xl">{{ getFlag(lang.code) }}</span>
              <div class="flex-1 min-w-0">
                <div class="font-semibold text-gray-900 truncate">{{ lang.name }}</div>
                <div class="text-xs text-gray-500 flex items-center gap-2">
                  <span class="uppercase font-mono">{{ lang.code }}</span>
                  <span>•</span>
                  <span>{{ formatDate(lang.updatedAt) }}</span>
                </div>
              </div>
              <i v-if="selectedLanguage?.code === lang.code" class="fas fa-check text-blue-600"></i>
            </div>
          </div>
          
          <div v-if="filteredLanguages.length === 0" class="text-center py-8 text-gray-500">
            <i class="fas fa-inbox text-4xl mb-2"></i>
            <p>No languages found</p>
          </div>
        </nav>
        
        <div class="p-4 border-t text-center text-sm text-gray-500">
          {{ languages.length }} language(s) total
        </div>
      </aside>
      
      <!-- Main Content -->
      <main class="flex-1 overflow-auto">
        <div v-if="selectedLanguage" class="p-8 max-w-5xl mx-auto">
          <!-- Header -->
          <div class="flex items-start justify-between mb-8">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <span class="text-4xl">{{ getFlag(selectedLanguage.code) }}</span>
                <div>
                  <h2 class="text-3xl font-bold text-gray-900">{{ selectedLanguage.name }}</h2>
                  <p class="text-gray-500">{{ selectedLanguage.nativeName }}</p>
                </div>
              </div>
              <div class="flex items-center gap-4 text-sm text-gray-600 mt-3">
                <span class="flex items-center gap-1">
                  <i class="fas fa-fingerprint text-gray-400"></i>
                  <span class="font-mono">{{ selectedLanguage.hash.substring(0, 8) }}...</span>
                </span>
                <span class="flex items-center gap-1">
                  <i class="fas fa-clock text-gray-400"></i>
                  Updated {{ formatDateRelative(selectedLanguage.updatedAt) }}
                </span>
                <span class="flex items-center gap-1">
                  <i class="fas fa-key text-gray-400"></i>
                  {{ translationCount }} keys
                </span>
              </div>
            </div>
            <div class="flex gap-2">
              <button @click="showCloneModal = true" class="btn-secondary flex items-center gap-2">
                <i class="fas fa-copy"></i>
                Clone
              </button>
              <button @click="exportLanguage" class="btn-secondary flex items-center gap-2">
                <i class="fas fa-download"></i>
                Export
              </button>
              <button @click="showImportModal = true" class="btn-secondary flex items-center gap-2">
                <i class="fas fa-upload"></i>
                Import
              </button>
              <button 
                @click="saveLanguage" 
                :disabled="!hasChanges || saving"
                class="btn-primary flex items-center gap-2"
              >
                <i v-if="saving" class="fas fa-spinner fa-spin"></i>
                <i v-else class="fas fa-save"></i>
                {{ saving ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>
          </div>
          
          <!-- Metadata Card -->
          <div class="bg-white rounded-xl shadow-sm border p-6 mb-6">
            <h3 class="text-lg font-semibold mb-4 flex items-center gap-2">
              <i class="fas fa-info-circle text-blue-600"></i>
              Metadata
            </h3>
            <div class="grid grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Code</label>
                <input 
                  v-model="form.code" 
                  disabled
                  class="w-full px-3 py-2 border rounded-lg bg-gray-50 text-gray-500 font-mono uppercase"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input 
                  v-model="form.name" 
                  @input="markChanged"
                  class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Native Name</label>
                <input 
                  v-model="form.nativeName" 
                  @input="markChanged"
                  class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                />
              </div>
            </div>
          </div>
          
          <!-- Translations Editor -->
          <div class="bg-white rounded-xl shadow-sm border">
            <div class="p-6 border-b flex items-center justify-between">
              <h3 class="text-lg font-semibold flex items-center gap-2">
                <i class="fas fa-language text-blue-600"></i>
                Translations
              </h3>
              <button @click="addTranslationKey" class="btn-primary text-sm flex items-center gap-2">
                <i class="fas fa-plus"></i>
                Add Key
              </button>
            </div>
            
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead class="bg-gray-50 border-b">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider w-1/3">Key</th>
                    <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Value</th>
                    <th class="px-6 py-3 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider w-20">Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                  <tr v-for="(value, key) in flatTranslations" :key="key" class="hover:bg-gray-50">
                    <td class="px-6 py-3">
                      <code class="text-sm font-mono text-gray-700 bg-gray-100 px-2 py-1 rounded">{{ key }}</code>
                    </td>
                    <td class="px-6 py-3">
                      <input
                        v-model="flatTranslations[key]"
                        @input="markChanged"
                        class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm"
                        placeholder="Enter translation..."
                      />
                    </td>
                    <td class="px-6 py-3 text-center">
                      <button 
                        @click="removeKey(key)" 
                        class="text-red-500 hover:text-red-700 p-2 rounded-lg hover:bg-red-50 transition-colors"
                        title="Delete key"
                      >
                        <i class="fas fa-trash-alt"></i>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            
            <div v-if="Object.keys(flatTranslations).length === 0" class="text-center py-12 text-gray-500">
              <i class="fas fa-key text-4xl mb-3 text-gray-300"></i>
              <p>No translation keys yet</p>
              <button @click="addTranslationKey" class="btn-primary mt-4">
                <i class="fas fa-plus mr-2"></i>
                Add First Key
              </button>
            </div>
          </div>
          
          <!-- Danger Zone -->
          <div class="bg-red-50 border border-red-200 rounded-xl p-6 mt-6">
            <h3 class="text-lg font-semibold text-red-800 mb-2 flex items-center gap-2">
              <i class="fas fa-exclamation-triangle"></i>
              Danger Zone
            </h3>
            <p class="text-red-600 mb-4">Once deleted, this language cannot be recovered.</p>
            <button @click="confirmDelete" class="btn-danger flex items-center gap-2">
              <i class="fas fa-trash-alt"></i>
              Delete Language
            </button>
          </div>
        </div>
        
        <!-- Empty State -->
        <div v-else class="flex items-center justify-center h-full">
          <div class="text-center text-gray-400">
            <i class="fas fa-mouse-pointer text-6xl mb-4"></i>
            <p class="text-xl">Select a language from the sidebar to edit</p>
          </div>
        </div>
      </main>
    </div>
    
    <!-- Add Language Modal -->
    <div v-if="showAddModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="showAddModal = false">
      <div class="bg-white rounded-xl shadow-2xl w-full max-w-md mx-4">
        <div class="p-6 border-b">
          <h3 class="text-xl font-bold">Add New Language</h3>
        </div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Language Code (2 letters)</label>
            <input 
              v-model="newLanguage.code" 
              maxlength="2"
              placeholder="en"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none font-mono uppercase"
            />
            <p class="text-xs text-gray-500 mt-1">e.g., en, de, es, fr</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input 
              v-model="newLanguage.name" 
              placeholder="English"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Native Name</label>
            <input 
              v-model="newLanguage.nativeName" 
              placeholder="English"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            />
          </div>
        </div>
        <div class="p-6 border-t flex justify-end gap-3">
          <button @click="showAddModal = false" class="btn-secondary">Cancel</button>
          <button 
            @click="createLanguage" 
            :disabled="!canCreate || creating"
            class="btn-primary"
          >
            <i v-if="creating" class="fas fa-spinner fa-spin mr-2"></i>
            {{ creating ? 'Creating...' : 'Create Language' }}
          </button>
        </div>
      </div>
    </div>
    
    <!-- Clone Language Modal -->
    <div v-if="showCloneModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="showCloneModal = false">
      <div class="bg-white rounded-xl shadow-2xl w-full max-w-md mx-4">
        <div class="p-6 border-b">
          <h3 class="text-xl font-bold">Clone Language</h3>
          <p class="text-gray-500 mt-1">Create a copy of {{ selectedLanguage?.name }}</p>
        </div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">New Language Code</label>
            <input 
              v-model="cloneCode" 
              maxlength="2"
              placeholder="es"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none font-mono uppercase"
            />
          </div>
        </div>
        <div class="p-6 border-t flex justify-end gap-3">
          <button @click="showCloneModal = false" class="btn-secondary">Cancel</button>
          <button 
            @click="cloneLanguage" 
            :disabled="!cloneCode || cloning"
            class="btn-primary"
          >
            <i v-if="cloning" class="fas fa-spinner fa-spin mr-2"></i>
            {{ cloning ? 'Cloning...' : 'Clone Language' }}
          </button>
        </div>
      </div>
    </div>
    
    <!-- Import Modal -->
    <div v-if="showImportModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="showImportModal = false">
      <div class="bg-white rounded-xl shadow-2xl w-full max-w-lg mx-4">
        <div class="p-6 border-b">
          <h3 class="text-xl font-bold">Import Translations</h3>
        </div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Import Mode</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="radio" v-model="importMode" value="merge" class="text-blue-600" />
                <span>Merge with existing</span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="radio" v-model="importMode" value="replace" class="text-blue-600" />
                <span>Replace all</span>
              </label>
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">JSON File</label>
            <textarea
              v-model="importJson"
              rows="10"
              placeholder='Paste JSON here... e.g., {&quot;main&quot;: {&quot;title&quot;: &quot;Hello&quot;}}'
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none font-mono text-sm"
            ></textarea>
          </div>
        </div>
        <div class="p-6 border-t flex justify-end gap-3">
          <button @click="showImportModal = false" class="btn-secondary">Cancel</button>
          <button 
            @click="importTranslations" 
            :disabled="!importJson || importing"
            class="btn-primary"
          >
            <i v-if="importing" class="fas fa-spinner fa-spin mr-2"></i>
            {{ importing ? 'Importing...' : 'Import' }}
          </button>
        </div>
      </div>
    </div>
    
    <!-- Toast Notifications -->
    <div class="fixed bottom-4 right-4 z-50 space-y-2">
      <transition-group name="fade">
        <div
          v-for="toast in toasts"
          :key="toast.id"
          :class="{
            'bg-green-500': toast.type === 'success',
            'bg-red-500': toast.type === 'error',
            'bg-blue-500': toast.type === 'info'
          }"
          class="text-white px-4 py-3 rounded-lg shadow-lg flex items-center gap-3 min-w-[300px]"
        >
          <i :class="{
            'fas fa-check-circle': toast.type === 'success',
            'fas fa-exclamation-circle': toast.type === 'error',
            'fas fa-info-circle': toast.type === 'info'
          }"></i>
          <span class="flex-1">{{ toast.message }}</span>
          <button @click="removeToast(toast.id)" class="text-white/80 hover:text-white">
            <i class="fas fa-times"></i>
          </button>
        </div>
      </transition-group>
    </div>
  </div>

  <script>
    const { createApp, ref, reactive, computed, onMounted } = Vue;

    createApp({
      setup() {
        // State
        const languages = ref([]);
        const selectedLanguage = ref(null);
        const searchQuery = ref('');
        const hasChanges = ref(false);
        const saving = ref(false);
        const creating = ref(false);
        const cloning = ref(false);
        const importing = ref(false);
        
        // Modals
        const showAddModal = ref(false);
        const showCloneModal = ref(false);
        const showImportModal = ref(false);
        
        // Forms
        const form = reactive({});
        const flatTranslations = reactive({});
        const newLanguage = reactive({ code: '', name: '', nativeName: '' });
        const cloneCode = ref('');
        const importMode = ref('merge');
        const importJson = ref('');
        
        // Toast
        const toasts = ref([]);
        let toastId = 0;

        // Computed
        const filteredLanguages = computed(() => {
          if (!searchQuery.value) return languages.value;
          const query = searchQuery.value.toLowerCase();
          return languages.value.filter(lang => 
            lang.name.toLowerCase().includes(query) ||
            lang.code.toLowerCase().includes(query) ||
            (lang.nativeName && lang.nativeName.toLowerCase().includes(query))
          );
        });

        const translationCount = computed(() => Object.keys(flatTranslations).length);

        const canCreate = computed(() => {
          return newLanguage.code.length === 2 && 
                 newLanguage.name.trim() && 
                 !languages.value.find(l => l.code === newLanguage.code.toLowerCase());
        });

        // Methods
        const showToast = (message, type = 'info') => {
          const id = ++toastId;
          toasts.value.push({ id, message, type });
          setTimeout(() => removeToast(id), 5000);
        };

        const removeToast = (id) => {
          const index = toasts.value.findIndex(t => t.id === id);
          if (index > -1) toasts.value.splice(index, 1);
        };

        const fetchLanguages = async () => {
          try {
            const response = await fetch('/languages');
            languages.value = await response.json();
          } catch (error) {
            showToast('Failed to load languages', 'error');
          }
        };

        const selectLanguage = async (lang) => {
          try {
            const response = await fetch(\`/languages/\${lang.code}\`);
            const fullLang = await response.json();
            selectedLanguage.value = fullLang;
            Object.assign(form, {
              code: fullLang.code,
              name: fullLang.name,
              nativeName: fullLang.nativeName
            });
            const flat = flattenTranslations(fullLang.translations || {});
            Object.keys(flatTranslations).forEach(key => delete flatTranslations[key]);
            Object.assign(flatTranslations, flat);
            hasChanges.value = false;
          } catch (error) {
            showToast('Failed to load language details', 'error');
          }
        };

        const createLanguage = async () => {
          creating.value = true;
          try {
            const response = await fetch('/languages', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                code: newLanguage.code.toLowerCase(),
                name: newLanguage.name,
                nativeName: newLanguage.nativeName,
                translations: {}
              })
            });
            if (response.ok) {
              showToast('Language created successfully', 'success');
              showAddModal.value = false;
              newLanguage.code = '';
              newLanguage.name = '';
              newLanguage.nativeName = '';
              await fetchLanguages();
            } else {
              const error = await response.json();
              showToast(error.error || 'Failed to create language', 'error');
            }
          } catch (error) {
            showToast('Failed to create language', 'error');
          } finally {
            creating.value = false;
          }
        };

        const saveLanguage = async () => {
          saving.value = true;
          try {
            // Save metadata
            await fetch(\`/languages/\${form.code}\`, {
              method: 'PATCH',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                name: form.name,
                nativeName: form.nativeName
              })
            });

            // Save translations
            const translations = unflattenTranslations(flatTranslations);
            await fetch(\`/languages/\${form.code}/translations\`, {
              method: 'PUT',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ translations })
            });

            showToast('Language saved successfully', 'success');
            hasChanges.value = false;
            await fetchLanguages();
            await selectLanguage({ code: form.code });
          } catch (error) {
            showToast('Failed to save language', 'error');
          } finally {
            saving.value = false;
          }
        };

        const cloneLanguage = async () => {
          cloning.value = true;
          try {
            const response = await fetch('/languages', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                code: cloneCode.value.toLowerCase(),
                name: \`\${form.name} (Copy)\`,
                nativeName: form.nativeName,
                translations: unflattenTranslations(flatTranslations)
              })
            });
            if (response.ok) {
              showToast('Language cloned successfully', 'success');
              showCloneModal.value = false;
              cloneCode.value = '';
              await fetchLanguages();
            } else {
              const error = await response.json();
              showToast(error.error || 'Failed to clone language', 'error');
            }
          } catch (error) {
            showToast('Failed to clone language', 'error');
          } finally {
            cloning.value = false;
          }
        };

        const confirmDelete = async () => {
          if (!confirm(\`Are you sure you want to delete "\${form.name}"? This action cannot be undone.\`)) return;
          
          try {
            const response = await fetch(\`/languages/\${form.code}\`, { method: 'DELETE' });
            if (response.ok) {
              showToast('Language deleted successfully', 'success');
              selectedLanguage.value = null;
              await fetchLanguages();
            } else {
              showToast('Failed to delete language', 'error');
            }
          } catch (error) {
            showToast('Failed to delete language', 'error');
          }
        };

        const exportLanguage = () => {
          const data = {
            code: form.code,
            name: form.name,
            nativeName: form.nativeName,
            translations: unflattenTranslations(flatTranslations)
          };
          const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = \`\${form.code}-translations.json\`;
          a.click();
          URL.revokeObjectURL(url);
          showToast('Language exported successfully', 'success');
        };

        const importTranslations = async () => {
          importing.value = true;
          try {
            const imported = JSON.parse(importJson.value);
            const translations = imported.translations || imported;
            
            if (importMode.value === 'merge') {
              const current = unflattenTranslations(flatTranslations);
              const merged = deepMerge(current, translations);
              Object.keys(flatTranslations).forEach(key => delete flatTranslations[key]);
              Object.assign(flatTranslations, flattenTranslations(merged));
            } else {
              Object.keys(flatTranslations).forEach(key => delete flatTranslations[key]);
              Object.assign(flatTranslations, flattenTranslations(translations));
            }
            
            hasChanges.value = true;
            showImportModal.value = false;
            importJson.value = '';
            showToast(\`Translations \${importMode.value === 'merge' ? 'merged' : 'replaced'} successfully\`, 'success');
          } catch (error) {
            showToast('Invalid JSON format', 'error');
          } finally {
            importing.value = false;
          }
        };

        const addTranslationKey = () => {
          const key = prompt('Enter key (use dots for nesting, e.g., "main.title"):');
          if (key && !flatTranslations[key]) {
            flatTranslations[key] = '';
            hasChanges.value = true;
          }
        };

        const removeKey = (key) => {
          if (confirm(\`Delete key "\${key}"?\`)) {
            delete flatTranslations[key];
            hasChanges.value = true;
          }
        };

        const markChanged = () => {
          hasChanges.value = true;
        };

        // Helpers
        const flattenTranslations = (obj, prefix = '') => {
          const result = {};
          for (const key in obj) {
            const newKey = prefix ? \`\${prefix}.\${key}\` : key;
            if (typeof obj[key] === 'object' && obj[key] !== null && !Array.isArray(obj[key])) {
              Object.assign(result, flattenTranslations(obj[key], newKey));
            } else {
              result[newKey] = String(obj[key]);
            }
          }
          return result;
        };

        const unflattenTranslations = (flat) => {
          const result = {};
          for (const key in flat) {
            const keys = key.split('.');
            let current = result;
            for (let i = 0; i < keys.length - 1; i++) {
              current[keys[i]] = current[keys[i]] || {};
              current = current[keys[i]];
            }
            current[keys[keys.length - 1]] = flat[key];
          }
          return result;
        };

        const deepMerge = (target, source) => {
          if (typeof target !== 'object' || target === null) return source;
          if (typeof source !== 'object' || source === null) return target;
          const result = { ...target };
          for (const key in source) {
            if (source.hasOwnProperty(key)) {
              if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
                result[key] = deepMerge(result[key], source[key]);
              } else {
                result[key] = source[key];
              }
            }
          }
          return result;
        };

        const getFlag = (code) => {
          const flags = {
            en: '🇺🇸', de: '🇩🇪', es: '🇪🇸', fr: '🇫🇷', it: '🇮🇹',
            pt: '🇵🇹', ru: '🇷🇺', ja: '🇯🇵', ko: '🇰🇷', zh: '🇨🇳',
            ar: '🇸🇦', hi: '🇮🇳', tr: '🇹🇷', pl: '🇵🇱', nl: '🇳🇱',
            sv: '🇸🇪', da: '🇩🇰', fi: '🇫🇮', no: '🇳🇴', cs: '🇨🇿',
            hu: '🇭🇺', ro: '🇷🇴', uk: '🇺🇦', th: '🇹🇭', vi: '🇻🇳',
            id: '🇮🇩', ms: '🇲🇾', fa: '🇮🇷', he: '🇮🇱', el: '🇬🇷'
          };
          return flags[code] || '🏳️';
        };

        const formatDate = (dateString) => {
          return new Date(dateString).toLocaleDateString();
        };

        const formatDateRelative = (dateString) => {
          const date = new Date(dateString);
          const now = new Date();
          const diff = (now - date) / 1000;
          
          if (diff < 60) return 'just now';
          if (diff < 3600) return \`\${Math.floor(diff / 60)}m ago\`;
          if (diff < 86400) return \`\${Math.floor(diff / 3600)}h ago\`;
          if (diff < 604800) return \`\${Math.floor(diff / 86400)}d ago\`;
          return date.toLocaleDateString();
        };

        onMounted(fetchLanguages);

        return {
          languages,
          selectedLanguage,
          searchQuery,
          hasChanges,
          saving,
          creating,
          cloning,
          importing,
          showAddModal,
          showCloneModal,
          showImportModal,
          form,
          flatTranslations,
          newLanguage,
          cloneCode,
          importMode,
          importJson,
          toasts,
          filteredLanguages,
          translationCount,
          canCreate,
          showToast,
          removeToast,
          fetchLanguages,
          selectLanguage,
          createLanguage,
          saveLanguage,
          cloneLanguage,
          confirmDelete,
          exportLanguage,
          importTranslations,
          addTranslationKey,
          removeKey,
          markChanged,
          getFlag,
          formatDate,
          formatDateRelative
        };
      }
    }).mount('#app');
  </script>
</body>
</html>`;

// Health check
app.get("/", (c) => {
  return c.json({
    status: "ok",
    service: "slang-cloud-server",
    version: "1.0.0",
    languages: database.size,
    admin: "/admin",
  });
});

// Admin Panel
app.get("/admin", (c) => {
  return c.html(adminHtml);
});

// ============================================
// TRANSLATION ENDPOINTS (for slang_cloud)
// ============================================

// HEAD /translations/:locale - Check version
app.on("HEAD", "/translations/:locale", (c) => {
  const locale = c.req.param("locale");
  const language = database.get(locale);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  c.header("X-Translation-Hash", language.hash);
  c.header("Content-Type", "application/json");
  return c.body(null, 200);
});

// GET /translations/:locale - Download translations
app.get("/translations/:locale", (c) => {
  const locale = c.req.param("locale");
  const language = database.get(locale);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  c.header("X-Translation-Hash", language.hash);
  return c.json(language.translations);
});

// ============================================
// LANGUAGE MANAGEMENT ENDPOINTS
// ============================================

// GET /languages - List all languages (metadata only)
app.get("/languages", (c) => {
  const languages = Array.from(database.values()).map((lang) => ({
    code: lang.code,
    name: lang.name,
    nativeName: lang.nativeName,
    hash: lang.hash,
    updatedAt: lang.updatedAt.toISOString(),
  }));

  return c.json(languages);
});

// GET /languages/:code - Get single language with translations
app.get("/languages/:code", (c) => {
  const code = c.req.param("code");
  const language = database.get(code);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  return c.json({
    code: language.code,
    name: language.name,
    nativeName: language.nativeName,
    translations: language.translations,
    hash: language.hash,
    createdAt: language.createdAt.toISOString(),
    updatedAt: language.updatedAt.toISOString(),
  });
});

// POST /languages - Create new language
app.post("/languages", async (c) => {
  try {
    const body = await c.req.json<CreateLanguageRequest>();

    // Validation
    if (!body.code || typeof body.code !== "string" || body.code.length !== 2) {
      return c.json(
        { error: "Invalid code. Must be 2 character language code" },
        400
      );
    }

    if (!body.name || typeof body.name !== "string") {
      return c.json({ error: "Name is required" }, 400);
    }

    const code = body.code.toLowerCase();

    if (database.has(code)) {
      return c.json({ error: "Language already exists" }, 409);
    }

    const language = createLanguage({
      ...body,
      code,
    });

    database.set(code, language);

    return c.json(
      {
        code: language.code,
        name: language.name,
        nativeName: language.nativeName,
        hash: language.hash,
        createdAt: language.createdAt.toISOString(),
        updatedAt: language.updatedAt.toISOString(),
      },
      201
    );
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// PUT /languages/:code - Full replace language
app.put("/languages/:code", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<CreateLanguageRequest>();

    if (body.name && typeof body.name !== "string") {
      return c.json({ error: "Invalid name" }, 400);
    }

    const translations = body.translations
      ? validateTranslations(body.translations)
      : existing.translations;

    const updated: Language = {
      ...existing,
      name: body.name || existing.name,
      nativeName: body.nativeName !== undefined
        ? body.nativeName
        : existing.nativeName,
      translations,
      hash: calculateHash(translations),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      name: updated.name,
      nativeName: updated.nativeName,
      hash: updated.hash,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// PATCH /languages/:code - Partial update metadata only
app.patch("/languages/:code", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<Partial<CreateLanguageRequest>>();

    if (body.name !== undefined && typeof body.name !== "string") {
      return c.json({ error: "Invalid name" }, 400);
    }

    const updated: Language = {
      ...existing,
      name: body.name !== undefined ? body.name : existing.name,
      nativeName: body.nativeName !== undefined
        ? body.nativeName
        : existing.nativeName,
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      name: updated.name,
      nativeName: updated.nativeName,
      hash: updated.hash,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// DELETE /languages/:code - Delete language
app.delete("/languages/:code", (c) => {
  const code = c.req.param("code").toLowerCase();

  if (!database.has(code)) {
    return c.json({ error: "Language not found" }, 404);
  }

  database.delete(code);
  return c.json({ message: "Language deleted successfully" });
});

// ============================================
// TRANSLATION MANAGEMENT ENDPOINTS
// ============================================

// GET /languages/:code/translations - Get translations only
app.get("/languages/:code/translations", (c) => {
  const code = c.req.param("code").toLowerCase();
  const language = database.get(code);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  return c.json({
    translations: language.translations,
    hash: language.hash,
    updatedAt: language.updatedAt.toISOString(),
  });
});

// PUT /languages/:code/translations - Full replace translations
app.put("/languages/:code/translations", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<UpdateTranslationsRequest>();

    if (!body.translations) {
      return c.json({ error: "translations field is required" }, 400);
    }

    const translations = validateTranslations(body.translations);

    const updated: Language = {
      ...existing,
      translations,
      hash: calculateHash(translations),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      hash: updated.hash,
      updatedAt: updated.updatedAt.toISOString(),
      translations: updated.translations,
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// PATCH /languages/:code/translations - Merge/patch translations
app.patch("/languages/:code/translations", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<UpdateTranslationsRequest>();

    if (!body.translations) {
      return c.json({ error: "translations field is required" }, 400);
    }

    const patch = validateTranslations(body.translations);
    const merged = deepMerge(existing.translations, patch);

    const updated: Language = {
      ...existing,
      translations: merged,
      hash: calculateHash(merged),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      hash: updated.hash,
      updatedAt: updated.updatedAt.toISOString(),
      translations: updated.translations,
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// POST /languages/:code/translations - Add/update specific keys
app.post("/languages/:code/translations", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<Record<string, any>>();

    // Validate that body is an object
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      return c.json({ error: "Request body must be a JSON object" }, 400);
    }

    // Merge with existing
    const merged = deepMerge(existing.translations, body);

    const updated: Language = {
      ...existing,
      translations: merged,
      hash: calculateHash(merged),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      hash: updated.hash,
      updatedAt: updated.updatedAt.toISOString(),
      translations: updated.translations,
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// Start server
seedDatabase();

const port = process.env.PORT || 3000;
console.log(`🚀 Slang Cloud Server running on http://localhost:${port}`);
console.log(`📖 API Documentation: http://localhost:${port}/`);
console.log(`🎛️  Admin Panel: http://localhost:${port}/admin`);
console.log(`⚡ Auto-reload enabled (bun --watch)`);

export default {
  port,
  fetch: app.fetch,
};
