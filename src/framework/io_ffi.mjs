export const resolve = (value) => Promise.resolve(value);
export const then = (value, next) => value.then(next);
export const commit = (context, carry) => context.commit(carry);
export const finish = (context) => context.finish();
