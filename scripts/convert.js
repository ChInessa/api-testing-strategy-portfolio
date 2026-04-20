const fs = require("fs");
const path = require("path");
const { transpile } = require("postman2openapi");

let yaml;
try {
  yaml = require("js-yaml");
} catch (e) {
  try {
    yaml = require("postman-to-openapi/node_modules/js-yaml");
  } catch (e2) {
    console.error("Ошибка: не удалось загрузить js-yaml. Установите его: npm install js-yaml");
    process.exit(1);
  }
}

const collectionsDir = path.join(__dirname, "../postman/collections");
const specsDir = path.join(__dirname, "../postman/specs");

if (!fs.existsSync(specsDir)) {
  fs.mkdirSync(specsDir, { recursive: true });
}

function preprocessCollection(collection) {
  function traverse(obj) {
    if (Array.isArray(obj)) {
      obj.forEach(item => traverse(item));
    } else if (obj !== null && typeof obj === 'object') {
      if (obj.type === "default") obj.type = "string";
      
      if (obj.body?.mode === "raw" && obj.body.raw && obj.body.options?.raw?.language === "json") {
        try {
          let cleaned = obj.body.raw.split('\n').map(line => {
            const trimmed = line.trim();
            if (trimmed.startsWith('//')) return '';
            const commentIndex = line.indexOf('//');
            if (commentIndex > 0) {
              const beforeComment = line.substring(0, commentIndex);
              if ((beforeComment.match(/"/g) || []).length % 2 === 0) {
                return line.substring(0, commentIndex).trimEnd();
              }
            }
            return line;
          }).filter(line => line.length > 0).join('\n');
          
          cleaned = cleaned.replace(/\/\*[\s\S]*?\*\//g, '').replace(/,(\s*[}\]])/g, '$1');
          JSON.parse(cleaned);
          obj.body.raw = cleaned;
        } catch (e) {}
      }
      
      Object.keys(obj).forEach(key => traverse(obj[key]));
    }
  }
  
  traverse(collection);
  return collection;
}

function convertCollection(collectionPath) {
  const collectionName = path.basename(collectionPath, ".postman_collection.json");
  console.log(`Конвертация: ${collectionName}`);
  
  try {
    let collection = JSON.parse(fs.readFileSync(collectionPath, "utf8"));
    collection = preprocessCollection(collection);
    const openapi = transpile(collection);
    const outputPath = path.join(specsDir, `${collectionName}.yaml`);
    
    fs.writeFileSync(outputPath, yaml.dump(openapi, {
      indent: 2,
      lineWidth: -1,
      noRefs: false,
      quotingType: '"',
      sortKeys: false
    }), "utf8");
    
    console.log(`✓ Создан файл: ${outputPath}`);
    return { success: true, outputPath };
  } catch (error) {
    const errorMsg = error.message || error.toString() || "Неизвестная ошибка";
    console.error(`✗ Ошибка при конвертации ${collectionName}:`, errorMsg);
    if (process.env.DEBUG) console.error("Детали ошибки:", error.stack);
    return { success: false, error: errorMsg };
  }
}

function main() {
  const collectionFiles = fs.readdirSync(collectionsDir)
    .filter(file => file.endsWith(".postman_collection.json"));
  
  if (collectionFiles.length === 0) {
    console.log("Не найдено коллекций Postman для конвертации.");
    return;
  }
  
  console.log(`Найдено коллекций: ${collectionFiles.length}\n`);
  
  const results = collectionFiles.map(file => {
    try {
      return convertCollection(path.join(collectionsDir, file));
    } catch (error) {
      console.error(`Критическая ошибка при обработке ${file}:`, error.message);
      return { success: false, error: error.message };
    }
  });
  
  console.log("\n" + "=".repeat(50));
  const successful = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  
  console.log(`Успешно конвертировано: ${successful}`);
  if (failed > 0) console.log(`Ошибок: ${failed}`);
}

main();
