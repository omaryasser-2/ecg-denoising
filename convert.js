const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

const docsDir = path.join(__dirname, 'docs');

fs.readdir(docsDir, (err, files) => {
    if (err) {
        console.error('Error reading directory:', err);
        process.exit(1);
    }

    files.forEach(file => {
        if (path.extname(file) === '.md') {
            const mdFilePath = path.join(docsDir, file);
            const htmlFilePath = path.join(docsDir, file.replace(/\.md$/, '.html'));
            
            const markdownContent = fs.readFileSync(mdFilePath, 'utf8');
            const htmlContent = marked.parse(markdownContent);
            
            const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${file.replace(/\.md$/, '')}</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 2rem; color: #333; }
        pre { background-color: #f5f5f5; padding: 1rem; border-radius: 4px; overflow-x: auto; }
        code { font-family: monospace; background-color: #f5f5f5; padding: 0.2rem 0.4rem; border-radius: 3px; }
        img { max-width: 100%; height: auto; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 1rem; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    ${htmlContent}
</body>
</html>`;
            
            fs.writeFileSync(htmlFilePath, fullHtml, 'utf8');
            console.log(`Converted ${file} to ${path.basename(htmlFilePath)}`);
        }
    });
});
