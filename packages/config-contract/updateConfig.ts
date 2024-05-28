import fs from "fs";
import path from "path";

export const updateConfig = async (newConfig: unknown) => {
  const toWrite =
    `export const config = ` +
    JSON.stringify(newConfig, null, 2) +
    ";\n";

  fs.writeFileSync(path.join(__dirname, "config.ts"), toWrite);
};
