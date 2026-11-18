<template>
  <div class="about">
    <web-navbar :no-scroll="true"/>

    <main class="main-content">
      <div class="container">
        <p class="eyebrow">ABOUT</p>
        <h1 class="title">{{ websiteInfo.slogan_en || websiteInfo.title }}</h1>
        <p class="subtitle">{{ websiteInfo.slogan }}</p>

        <section class="profile">
          <div class="avatar">{{ (websiteInfo.slogan_en || 'Z').charAt(0) }}</div>

          <div class="details">
            <h2>{{ websiteInfo.name }}</h2>
            <p class="meta">
              {{ websiteInfo.job }}
              <span v-if="websiteInfo.address"> · {{ websiteInfo.address }}</span>
            </p>
            <p class="description">{{ websiteInfo.description }}</p>

            <div class="links">
              <a v-if="websiteInfo.email" :href="`mailto:${websiteInfo.email}`">
                {{ websiteInfo.email }}
              </a>
              <a
                  v-if="websiteInfo.github_url"
                  :href="websiteInfo.github_url"
                  target="_blank"
                  rel="noopener noreferrer"
              >
                GitHub ↗
              </a>
              <a
                  v-if="websiteInfo.gitee_url"
                  :href="websiteInfo.gitee_url"
                  target="_blank"
                  rel="noopener noreferrer"
              >
                Gitee ↗
              </a>
              <a
                  v-if="websiteInfo.bilibili_url"
                  :href="websiteInfo.bilibili_url"
                  target="_blank"
                  rel="noopener noreferrer"
              >
                Bilibili ↗
              </a>
            </div>
          </div>
        </section>

        <p class="since">
          建站于 {{ websiteInfo.created_at }}
          <span v-if="websiteInfo.version"> · {{ websiteInfo.version }}</span>
        </p>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import WebNavbar from "@/components/layout/WebNavbar.vue";
import {useWebsiteStore} from "@/stores/website";
import {computed} from "vue";

const websiteStore = useWebsiteStore()
const websiteInfo = computed(() => websiteStore.state.websiteInfo)
</script>

<style scoped lang="scss">
.about {
  min-height: 100vh;

  .main-content {
    display: flex;
    justify-content: center;
    padding: 140px 24px 80px;

    .container {
      width: 100%;
      max-width: 900px;
    }

    .eyebrow {
      margin: 0 0 18px;
      font-family: var(--font-mono);
      font-size: 13px;
      letter-spacing: 0.18em;
      color: var(--accent);
    }

    .title {
      margin: 0;
      font-family: var(--font-serif);
      font-size: clamp(64px, 12vw, 132px);
      font-weight: 400;
      line-height: 1;
      letter-spacing: -0.04em;
    }

    .subtitle {
      margin: 24px 0 56px;
      font-family: var(--font-mono);
      font-size: 15px;
      color: var(--ink-3);
    }

    .profile {
      display: flex;
      gap: 40px;
      border-top: 1px solid var(--line-strong);
      border-bottom: 1px solid var(--line-strong);
      padding: 48px 0;

      .avatar {
        display: flex;
        align-items: center;
        justify-content: center;
        flex: 0 0 136px;
        width: 136px;
        height: 136px;
        border: 1px solid var(--line-strong);
        font-family: var(--font-serif);
        font-size: 64px;
        color: var(--accent);
        background: var(--accent-soft);
      }

      .details {
        min-width: 0;

        h2 {
          margin: 0 0 8px;
          font-family: var(--font-serif);
          font-size: 34px;
          font-weight: 400;
        }

        .meta {
          margin: 0 0 24px;
          font-family: var(--font-mono);
          font-size: 14px;
          color: var(--accent);
        }

        .description {
          max-width: 620px;
          margin: 0 0 28px;
          font-family: var(--font-serif);
          font-size: 18px;
          line-height: 1.8;
          color: var(--ink-2);
        }

        .links {
          display: flex;
          flex-wrap: wrap;
          gap: 12px 24px;

          a {
            font-family: var(--font-mono);
            font-size: 14px;
            color: var(--ink-2);
            text-decoration: none;
            transition: color 0.2s ease;

            &:hover {
              color: var(--accent);
            }
          }
        }
      }
    }

    .since {
      margin: 24px 0 0;
      font-family: var(--font-mono);
      font-size: 12px;
      color: var(--ink-3);
      text-align: right;
    }
  }
}

@media (max-width: 768px) {
  .about .main-content {
    padding: 110px 20px 56px;

    .profile {
      flex-direction: column;
      gap: 24px;

      .avatar {
        flex-basis: 96px;
        width: 96px;
        height: 96px;
        font-size: 44px;
      }
    }

    .since {
      text-align: left;
    }
  }
}
</style>
