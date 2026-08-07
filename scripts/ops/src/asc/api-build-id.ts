import "dotenv/config";
import { ascApi } from "../lib/asc-api.js";

async function main() {
  const data = await ascApi<{ data: any[]; included?: any[] }>("/v1/builds", {
    query: { "filter[app]": "6760911210", sort: "-uploadedDate", limit: 5, include: "preReleaseVersion" },
  });
  for (const b of data.data.slice(0, 3)) {
    const preId = b.relationships?.preReleaseVersion?.data?.id;
    const ver = data.included?.find((i) => i.id === preId)?.attributes.version;
    console.log(`${ver} buildId=${b.id} buildNum=${b.attributes.version}`);
  }
}

main();
