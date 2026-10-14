(() => {
  const scene = document.getElementById('scene');
  if (!scene) return;

  const fitScene = () => {
    const height = Number(scene.dataset.h) || scene.offsetHeight;
    const scale = Math.min(window.innerWidth / 1667, window.innerHeight / height);
    scene.style.setProperty('--scene-scale', String(scale));
  };

  fitScene();
  window.addEventListener('resize', fitScene);
})();
