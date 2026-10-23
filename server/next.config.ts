import { withDylKit } from "@dylkit/web/config";

export default withDylKit({
  experimental: {
    serverActions: {
      bodySizeLimit: "12mb",
    },
  },
});
