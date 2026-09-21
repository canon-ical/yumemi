import * as worker from "./build/dev/javascript/yumemi_front_scratch/worker.mjs";

export default {
  fetch(request, env, context) {
    return worker.fetch(request, env, context);
  },
};
